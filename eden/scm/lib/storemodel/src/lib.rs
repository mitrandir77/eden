/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! # storemodel
//!
//! Provides trait definitions for storage needs.
//! Useful to de-couple from heavyweight storage implementations.
//!
//! Traits defined by this crate are ideally tech-debt free and
//! consider both hg and git use-cases. This mainly means:
//! - APIs do expose hg details like filelog "copy from" or LFS pointer.
//! - History-related APIs should avoid linkrev or linknode, which do not exist
//!   in git.
//!
//! For flexibility, different features might be defined in different traits.
//! Traits can be combined later. For example, reading file content, metadata,
//! and history should probably be 3 different traits.

use std::any::Any;
use std::path::Path;
use std::sync::Arc;

use async_trait::async_trait;
use edenapi_trait::SaplingRemoteApi;
use edenapi_types::DirectoryMetadata;
pub use edenapi_types::FileAuxData;
pub use futures;
use metalog::MetaLog;
pub use minibytes;
pub use minibytes::Bytes;
use once_cell::sync::OnceCell;
use parking_lot::RwLock;
use serde::Deserialize;
use serde::Serialize;
pub use types;
use types::fetch_mode::FetchMode;
pub use types::tree::TreeItemFlag;
use types::HgId;
use types::Key;
use types::PathComponent;
use types::PathComponentBuf;
use types::RepoPath;

/// Boxed dynamic iterator. Similar to `BoxStream`.
pub type BoxIterator<'a, T> = Box<dyn Iterator<Item = T> + Send + 'a>;

/// A store where content is indexed by "(path, hash)", aka "Key".
pub trait KeyStore: Send + Sync {
    /// Read the content of specified files.
    ///
    /// The returned content should be just the file contents. This means:
    /// - The returned content does not contain the "copy from" header.
    /// - The returned content does not contain raw LFS content. LFS pointer
    ///   is resolved transparently.
    ///
    /// Fetch mode is ignored in this prototype method
    /// The iterator might block waiting for network.
    fn get_content_iter(
        &self,
        keys: Vec<Key>,
        _fetch_mode: FetchMode,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, Bytes)>>> {
        let iter = keys
            .into_iter()
            .map(|k| match self.get_local_content(&k.path, k.hgid) {
                Err(e) => Err(e),
                Ok(None) => Err(anyhow::format_err!(
                    "{}@{}: not found locally",
                    k.path,
                    k.hgid
                )),
                Ok(Some(data)) => Ok((k, data)),
            });
        Ok(Box::new(iter))
    }

    /// Read the content of the specified file without connecting to a remote server.
    /// Return `None` if the file is not available locally.
    fn get_local_content(
        &self,
        _path: &RepoPath,
        _hgid: HgId,
    ) -> anyhow::Result<Option<minibytes::Bytes>> {
        Ok(None)
    }

    /// Read the content of the specified file. Ask a remote server on demand.
    /// When fetching many files, use `get_content_iter` instead of calling
    /// this in a loop.
    fn get_content(
        &self,
        path: &RepoPath,
        hgid: HgId,
        fetch_mode: FetchMode,
    ) -> anyhow::Result<minibytes::Bytes> {
        // Handle "broken" implementation that returns Err(_) not Ok(None) on not found.
        if !fetch_mode.is_remote() {
            if let Ok(Some(data)) = self.get_local_content(path, hgid) {
                return Ok(data);
            }
        }

        let key = Key::new(path.to_owned(), hgid);
        match self.get_content_iter(vec![key], fetch_mode)?.next() {
            None => Err(anyhow::format_err!("{}@{}: not found remotely", path, hgid)),
            Some(Err(e)) => Err(e),
            Some(Ok((_k, data))) => Ok(data),
        }
    }

    /// Indicate to the store that we will be attempting to access the given
    /// items soon. Some stores (especially ones that may perform network
    /// I/O) may use this information to prepare for these accesses (e.g., by
    /// by prefetching the nodes in bulk). For some stores this operation does
    /// not make sense, so the default implementation is a no-op.
    ///
    /// This is an old API. Consider `get_content_iter` instead.
    fn prefetch(&self, _keys: Vec<Key>) -> anyhow::Result<()> {
        Ok(())
    }

    /// Insert a serialized entry. Return the hash to the entry.
    ///
    /// After calling this function, the data can be fetched via
    /// `get_local_content` on the same store. The store can buffer pending data
    /// in memory until `flush()`, or `flush()` automatically to keep memory
    /// usage bounded.
    ///
    /// For stores using hg format:
    /// - `parents` is required, and will affect the hash.
    /// - `data` should contain the filelog metadata header.
    ///
    /// For stores using git format:
    /// - `parents` is a hint to choose delta base.
    /// - `data` is the pure content without headers.
    fn insert_data(
        &self,
        _opts: InsertOpts,
        _path: &RepoPath,
        _data: &[u8],
    ) -> anyhow::Result<HgId> {
        anyhow::bail!("store is read-only")
    }

    /// Write pending changes to disk.
    /// For some implementations, this also includes `refresh()`.
    fn flush(&self) -> anyhow::Result<()> {
        anyhow::bail!("store is read-only")
    }

    /// Refresh the store so it might pick up new contents written by other processes.
    /// For some implementations, this also includes `flush()`.
    fn refresh(&self) -> anyhow::Result<()> {
        Ok(())
    }

    /// Decides whether the store uses git or hg format.
    fn format(&self) -> SerializationFormat {
        SerializationFormat::Hg
    }

    /// Free-form statistics.
    fn statistics(&self) -> Vec<(String, usize)> {
        Vec::new()
    }

    /// Optional downcasting. If a store wants downcasting support, implement this
    /// as `Some(self)` explicitly.
    fn maybe_as_any(&self) -> Option<&dyn Any> {
        None
    }
}

/// A store for files.
pub trait FileStore: KeyStore + 'static {
    /// Read rename metadata of specified files.
    ///
    /// The result is a vector of (key, rename_from_key) pairs for files with
    /// rename information.
    ///
    /// The iterator might block waiting for network.
    fn get_rename_iter(
        &self,
        _keys: Vec<Key>,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, Key)>>> {
        Ok(Box::new(std::iter::empty()))
    }

    /// Get auxiliary metadata for a single file.
    /// Returns `None` if the information is unavailable locally.
    /// The default implementation falls back to calculating them from content.
    fn get_local_aux(&self, path: &RepoPath, id: HgId) -> anyhow::Result<Option<FileAuxData>> {
        Ok(self
            .get_local_content(path, id)?
            .map(|data| FileAuxData::from_content(&data)))
    }

    /// Get auxiliary metadata for the given files.
    /// Contact remote server on demand. Might block.
    /// The default implementation falls back to calculating them from content.
    fn get_aux_iter(
        &self,
        keys: Vec<Key>,
        fetch_mode: FetchMode,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, FileAuxData)>>> {
        let iter = self
            .get_content_iter(keys, fetch_mode)?
            .map(|entry| match entry {
                Err(e) => Err(e),
                Ok((key, data)) => Ok((key, FileAuxData::from_content(&data))),
            });
        Ok(Box::new(iter))
    }

    /// Get auxiliary metadata for the given file.
    /// Contact remote server on demand. Might block.
    /// When fetching many files, use `get_aux_iter` instead of calling this in a loop.
    fn get_aux(
        &self,
        path: &RepoPath,
        id: HgId,
        fetch_mode: FetchMode,
    ) -> anyhow::Result<FileAuxData> {
        let key = Key::new(path.to_owned(), id);
        match self.get_aux_iter(vec![key], fetch_mode)?.next() {
            None => Err(anyhow::format_err!("{}@{}: not found remotely", path, id)),
            Some(Err(e)) => Err(e),
            Some(Ok((_k, aux))) => Ok(aux),
        }
    }

    /// Get parents at the file store layer.
    /// This is only used by legacy Hg logic and is incompatible with Git.
    /// New logic should use `pathhistory` or server-provided history instead.
    fn get_hg_parents(&self, _path: &RepoPath, _id: HgId) -> anyhow::Result<Vec<HgId>> {
        Ok(Vec::new())
    }

    /// Get the "raw" content. For LFS this returns its raw pointer.
    /// This is only used by legacy Hg logic and is incompatible with Git.
    fn get_hg_raw_content(&self, path: &RepoPath, id: HgId) -> anyhow::Result<minibytes::Bytes> {
        // The default fetch mode is AllowRemote, which accesses both local and remote stores.
        self.get_content(path, id, FetchMode::AllowRemote)
    }

    /// Get the "raw" flags. For LFS this is non-zero.
    /// This is only used by legacy Hg logic and is incompatible with Git.
    fn get_hg_flags(&self, _path: &RepoPath, _id: HgId) -> anyhow::Result<u32> {
        Ok(0)
    }

    /// Upload LFS files specified by the keys.
    /// This is called before push.
    fn upload_lfs(&self, _keys: Vec<Key>) -> anyhow::Result<()> {
        Ok(())
    }

    fn as_key_store(&self) -> &dyn KeyStore
    where
        Self: Sized,
    {
        self
    }
}

#[async_trait]
pub trait ReadRootTreeIds {
    /// Read root tree nodes of given commits.
    /// Return `(commit_id, tree_id)` list.
    async fn read_root_tree_ids(&self, commits: Vec<HgId>) -> anyhow::Result<Vec<(HgId, HgId)>>;
}

/// Abstracted tree entry.
pub trait TreeEntry: Send + 'static {
    // PERF: PathComponentBuf is used because manifest-tree implementation detail.
    // There should be a way to avoid allocation.
    /// Iterate through the tree items.
    /// Note the iteration order is serialization format defined.
    /// Practically, Git appends `/` to directories when sorting them.
    fn iter(
        &self,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(PathComponentBuf, HgId, TreeItemFlag)>>>;

    /// Lookup a single item.
    /// The actual implementation might use bisect under the hood.
    /// Practically, only hg tree supports bisecting.
    fn lookup(&self, name: &PathComponent) -> anyhow::Result<Option<(HgId, TreeItemFlag)>>;

    /// Iterate through the file aux data if they are available.
    /// For performance reasons, the iteration is on `HgId`.
    fn file_aux_iter(&self) -> anyhow::Result<BoxIterator<anyhow::Result<(HgId, FileAuxData)>>> {
        Ok(Box::new(std::iter::empty()))
    }

    /// Iterate through the child directory metadata if they are available.
    /// For performance reasons, the iteration is on `HgId`.
    fn directory_metadata_iter(
        &self,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(HgId, DirectoryMetadata)>>> {
        Ok(Box::new(std::iter::empty()))
    }

    /// Get the directory metadata data of the tree.
    fn metadata(&self) -> anyhow::Result<Option<DirectoryMetadata>> {
        Ok(None)
    }
}

/// The `TreeStore` is an abstraction layer for the tree manifest that decouples how or where the
/// data is stored. This allows more easy iteration on serialization format. It also simplifies
/// writing storage migration.
pub trait TreeStore: KeyStore {
    /// List a tree with optional auxiliary metadata.
    /// Returns `None` if the information is unavailable locally.
    ///
    /// The default implementation does not provide the aux data.
    /// Currently mainly used by EdenFS.
    fn get_local_tree(
        &self,
        path: &RepoPath,
        id: HgId,
    ) -> anyhow::Result<Option<Box<dyn TreeEntry>>> {
        let data = match self.get_local_content(path, id)? {
            None => return Ok(None),
            Some(v) => v,
        };
        Ok(Some(basic_parse_tree(data, self.format())?))
    }

    fn get_remote_tree_iter(
        &self,
        _keys: Vec<Key>,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, Box<dyn TreeEntry>)>>> {
        // Function proto, let subclasses implement
        anyhow::bail!("Remote content iterator is not implemented")
    }

    /// List trees with optional auxiliary metadata.
    /// Get tree entries auxiliary metadata for the given files.
    /// Contact remote server on demand. Might block.
    ///
    /// Ignores fetch_mode in the default implementation
    /// Currently mainly used by EdenFS.
    fn get_tree_iter(
        &self,
        keys: Vec<Key>,
        _fetch_mode: FetchMode,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, Box<dyn TreeEntry>)>>> {
        let iter = keys
            .into_iter()
            .map(|k| match self.get_local_tree(&k.path, k.hgid) {
                Err(e) => Err(e),
                Ok(None) => Err(anyhow::format_err!(
                    "{}@{}: not found locally",
                    k.path,
                    k.hgid
                )),
                Ok(Some(data)) => Ok((k, data)),
            });
        Ok(Box::new(iter))
    }

    fn as_key_store(&self) -> &dyn KeyStore
    where
        Self: Sized,
    {
        self
    }

    /// Get directory metadata for a single tree.
    /// Returns `None` if the information is unavailable locally.
    fn get_local_directory_metadata(
        &self,
        path: &RepoPath,
        id: HgId,
    ) -> anyhow::Result<Option<DirectoryMetadata>> {
        match self.get_local_tree(path, id)? {
            None => Ok(None),
            Some(e) => e.metadata(),
        }
    }

    /// Get directory metadata for the given trees.
    /// Contact remote server on demand. Might block.
    fn get_directory_metadata_iter(
        &self,
        keys: Vec<Key>,
        fetch_mode: FetchMode,
    ) -> anyhow::Result<BoxIterator<anyhow::Result<(Key, DirectoryMetadata)>>> {
        let iter = self
            .get_tree_iter(keys, fetch_mode)?
            .map(|entry| match entry {
                Err(e) => Err(e),
                Ok((key, data)) => {
                    let metadata = data.metadata()?.ok_or_else(|| {
                        anyhow::anyhow!(format!("directory metadata is missing for key: {}", key))
                    })?;
                    Ok((key, metadata))
                }
            });
        Ok(Box::new(iter))
    }

    /// Get directory metadata for the given tree.
    /// Contact remote server on demand. Might block.
    /// When fetching data for many trees, use `get_directory_metadata_iter`
    /// instead of calling this in a loop.
    fn get_directory_metadata(
        &self,
        path: &RepoPath,
        id: HgId,
        fetch_mode: FetchMode,
    ) -> anyhow::Result<DirectoryMetadata> {
        let key = Key::new(path.to_owned(), id);
        match self.get_tree_iter(vec![key.clone()], fetch_mode)?.next() {
            None => Err(anyhow::format_err!("{}@{}: not found remotely", path, id)),
            Some(Err(e)) => Err(e),
            Some(Ok((_k, tree))) => tree.metadata()?.ok_or_else(|| {
                anyhow::anyhow!(format!("directory metadata is missing for key: {}", key))
            }),
        }
    }
}

/// Decides the serialization format. This exists so different parts of the code
/// base can agree on how to generate a SHA1, how to lookup in a tree, etc.
/// Ideally this information is private and the differences are behind
/// abstractions too.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash, Ord, PartialOrd)]
pub enum SerializationFormat {
    // Hg SHA1:
    //   SORTED_PARENTS CONTENT
    //
    // Hg file:
    //   FILELOG_METADATA CONTENT
    //
    // Hg tree:
    //   NAME '\0' HEX_SHA1 MODE '\n'
    //   MODE: 't' (tree), 'l' (symlink), 'x' (executable)
    //   (sorted by name)
    Hg,

    // Git SHA1:
    //   TYPE LENGTH CONTENT
    //
    // Git file:
    //   CONTENT
    //
    // Git tree:
    //   MODE ' ' NAME '\0' BIN_SHA1
    //   MODE: '40000' (tree), '100644' (regular), '100755' (executable),
    //         '120000' (symlink), '160000' (gitlink)
    //   (sorted by name, but directory names are treated as ending with '/')
    Git,
}

/// Options used by `insert_data`
#[derive(Deserialize, Default)]
pub struct InsertOpts {
    /// Parent hashes.
    /// For Hg it's required and affects SHA1.
    /// For Git it's a hint about the delta bases.
    pub parents: Vec<HgId>,

    /// Whether this is a file or a tree.
    /// For Hg it's ignored. For Git it affects SHA1.
    pub kind: Kind,

    /// Forced SHA1 to use. Mainly for testing purpose.
    #[serde(default)]
    pub forced_id: Option<Box<HgId>>,

    /// Hg flags to use. Used for legacy LFS support.
    #[serde(default)]
    pub hg_flags: u32,
}

/// Distinguish between a file and a tree.
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
#[derive(Default)]
pub enum Kind {
    #[default]
    File,
    Tree,
}

/// Provide information about how to build a file, tree or commit graph backend.
pub trait StoreInfo: 'static {
    /// Check requirement. Return `true` if the requirement is present.
    fn has_requirement(&self, requirement: &str) -> bool;
    /// Provides the config.
    fn config(&self) -> &dyn configmodel::Config;
    /// Provide the "storage path", which is usually `.sl/store` in the backing repo.
    fn store_path(&self) -> &Path;
    /// Provide the remote peer.
    fn remote_peer(&self) -> anyhow::Result<Option<Arc<dyn SaplingRemoteApi>>>;
    // Provide the metalog, useful to sync refs from git.
    fn metalog(&self) -> anyhow::Result<Arc<RwLock<MetaLog>>>;
}

/// Provide ways to obtain file and tree stores.
pub trait StoreOutput: 'static {
    /// Obtain the file store.
    fn file_store(&self) -> Arc<dyn FileStore>;

    /// Obtain the tree store.
    ///
    /// Based on the implementation, this might or might not be the same as the
    /// file store under the hood.
    fn tree_store(&self) -> Arc<dyn TreeStore>;
}

impl<T: FileStore + TreeStore> StoreOutput for Arc<T> {
    fn file_store(&self) -> Arc<dyn FileStore> {
        self.clone() as Arc<dyn FileStore>
    }

    fn tree_store(&self) -> Arc<dyn TreeStore> {
        self.clone() as Arc<dyn TreeStore>
    }
}

#[doc(hidden)]
pub type StaticSerializedTreeParseFunc =
    fn(Bytes, SerializationFormat) -> anyhow::Result<Box<dyn TreeEntry>>;

/// Parse a serialized git or hg tree into `TreeEntry`.
/// This is basic parsing that does not provide `FileAuxData`.
/// The actual implementation is elsewhere to avoid cyclic dependencies.
pub fn basic_parse_tree(
    data: Bytes,
    format: SerializationFormat,
) -> anyhow::Result<Box<dyn TreeEntry>> {
    // Only call `call_constructor` once to avoid overhead in `factory`.
    static TREE_PARSER: OnceCell<StaticSerializedTreeParseFunc> = OnceCell::new();
    let parse = TREE_PARSER
        .get_or_try_init(|| factory::call_constructor::<(), StaticSerializedTreeParseFunc>(&()))?;
    parse(data, format)
}
