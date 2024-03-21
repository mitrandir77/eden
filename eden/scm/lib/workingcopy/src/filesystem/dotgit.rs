/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Result;
use configmodel::Config;
use context::CoreContext;
use gitcompat::rungit::RunGitOptions;
use manifest_tree::TreeManifest;
use parking_lot::Mutex;
use pathmatcher::DynMatcher;
use storemodel::FileStore;
use treestate::treestate::TreeState;
use types::HgId;
use types::RepoPathBuf;
use vfs::VFS;

use crate::filesystem::FileSystem;
use crate::filesystem::PendingChange;

/// The `DotGitFileSystem` is similar to EdenFileSystem: The actual "tree state" is
/// tracked elsewhere. The "treestate" only tracks non-clean files (`git status`).
/// Instead of talking to EdenFS via Thrift, talk to `git` via CLI.
pub struct DotGitFileSystem {
    #[allow(unused)]
    treestate: Arc<Mutex<TreeState>>,
    vfs: VFS,
    store: Arc<dyn FileStore>,
    git: RunGitOptions,
}

impl DotGitFileSystem {
    pub fn new(
        treestate: Arc<Mutex<TreeState>>,
        vfs: VFS,
        store: Arc<dyn FileStore>,
        config: &dyn Config,
    ) -> Result<Self> {
        let git = RunGitOptions {
            git_dir: Some(vfs.root().join(".git")),
            ..RunGitOptions::from_config(config)
        };
        Ok(DotGitFileSystem {
            treestate,
            vfs,
            store,
            git,
        })
    }
}

impl FileSystem for DotGitFileSystem {
    fn pending_changes(
        &self,
        _ctx: &CoreContext,
        matcher: DynMatcher,
        _ignore_matcher: DynMatcher,
        _ignore_dirs: Vec<PathBuf>,
        include_ignored: bool,
    ) -> Result<Box<dyn Iterator<Item = Result<PendingChange>>>> {
        tracing::debug!(
            include_ignored = include_ignored,
            "pending_changes (DotGitFileSystem)"
        );
        // Run "git status".
        let args = [
            "--porcelain=1",
            "--ignore-submodules=dirty",
            "--untracked-files=all",
            "--no-renames",
            "-z",
            if include_ignored {
                "--ignored"
            } else {
                "--ignored=no"
            },
        ];
        let out = self.git.call("status", &args)?;

        // TODO: What to do with treestate?
        // TODO: Check submodule status.

        // Example output:
        //
        // M  FILE1
        // MM FILE2
        //  M FILE3
        // A  FILE4
        //  D FILE5
        // ?? FILE6
        // R  FILE7 -> FILE8 (with --renames)
        // D  FILE7          (with --no-renames)
        // A  FiLE8          (with --no-renames)
        // !! FILE9          (with --ignored)
        // AD FILE10         (added to index, deleted on disk)

        let changes: Vec<Result<PendingChange>> = out
            .stdout
            .split(|&c| c == 0)
            .filter_map(|line| -> Option<Result<PendingChange>> {
                if line.get(2) != Some(&b' ') {
                    // Unknown format. Ignore.
                    return None;
                }
                let path_bytes = line.get(3..)?;
                let path = RepoPathBuf::from_utf8(path_bytes.to_vec()).ok()?;
                match matcher.matches_file(&path) {
                    Ok(false) => return None,
                    Ok(true) => {}
                    Err(e) => return Some(Err(e)),
                }
                // Prefer "working copy" state. Fallback to index.
                let sign = if line[1] == b' ' { line[0] } else { line[1] };
                let change = match sign {
                    b'D' => PendingChange::Deleted(path),
                    b'!' => PendingChange::Ignored(path),
                    _ => PendingChange::Changed(path),
                };
                Some(Ok(change))
            })
            .collect();

        Ok(Box::new(changes.into_iter()))
    }

    fn sparse_matcher(
        &self,
        manifests: &[Arc<TreeManifest>],
        dot_dir: &'static str,
    ) -> Result<Option<DynMatcher>> {
        crate::sparse::sparse_matcher(
            &self.vfs,
            manifests,
            self.store.clone(),
            &self.vfs.root().join(dot_dir),
        )
    }

    fn set_parents(&self, p1: HgId, p2: Option<HgId>, p1_tree: Option<HgId>) -> Result<()> {
        tracing::debug!(p1=?p1, p2=?p2, p1_tree=?p1_tree, "set_parents (DotGitFileSystem)");
        let p1_hex = p1.to_hex();
        self.git.call("update-ref", &["HEAD", &p1_hex])?;
        // TODO: What to do with p2?
        Ok(())
    }
}
