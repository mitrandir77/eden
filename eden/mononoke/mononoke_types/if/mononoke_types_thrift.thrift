/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! ------------
//! IMPORTANT!!!
//! ------------
//! Do not change the order of the fields! Changing the order of the fields
//! results in compatible but *not* identical serializations, so hashes will
//! change.
//! ------------
//! IMPORTANT!!!
//! ------------

namespace py3 eden.mononoke.mononoke_types

include "eden/mononoke/mononoke_types/serialization/data.thrift"
include "eden/mononoke/mononoke_types/serialization/id.thrift"
include "eden/mononoke/mononoke_types/serialization/path.thrift"
include "eden/mononoke/mononoke_types/serialization/time.thrift"
include "eden/mononoke/mononoke_types/serialization/bonsai.thrift"

union RawBundle2 {
  1: binary Bytes;
}
struct FileUnode {
  1: list<id.FileUnodeId> parents;
  2: id.ContentId content_id;
  3: bonsai.FileType file_type;
  4: id.MPathHash path_hash;
  5: id.ChangesetId linknode;
} (rust.exhaustive)

union UnodeEntry {
  1: id.FileUnodeId File;
  2: id.ManifestUnodeId Directory;
}

struct ManifestUnode {
  1: list<id.ManifestUnodeId> parents;
  2: map<path.MPathElement, UnodeEntry> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) subentries;
  3: id.ChangesetId linknode;
} (rust.exhaustive)

struct DeletedManifest {
  1: optional id.ChangesetId linknode;
  2: map<path.MPathElement, id.DeletedManifestId> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) subentries;
} (rust.exhaustive)

const i32 MAP_SHARD_SIZE = 2000;
// Since thrift has no "generics", we store the values of the map as arbitrary
// byte arrays. When parsing this, we will make sure they have the correct type.
// When non-trivial, the MapValue will be a Thrift serialized form of the true value.
typedef data.LargeBinary MapValue

// When the number of values in a subtree is at most MAP_SHARD_SIZE
// We inline all of them on a single node. Notice we don't use prefix here for
// simplicity.
struct ShardedMapTerminalNode {
  // The key is the original map key minus the prefixes and edges from all
  // intermediate nodes in the path to this node.
  1: map<data.SmallBinary, MapValue> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) values;
} (rust.exhaustive)

// An intermediate node of the sharded map node tree, though it may have a
// value itself.
struct ShardedMapIntermediateNode {
  // Having this non-empty means this node was merged with its parents
  // since they had a single child only.
  1: data.SmallBinary prefix;
  // An intermediate node may have a single value.
  2: optional MapValue value;
  // Children of this node. We only store the first byte of the edge,
  // the remaining bytes are stored in the child node itself.
  3: map<byte, ShardedMapEdge> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) edges;
} (rust.exhaustive)

// An edge from a map node to another
struct ShardedMapEdge {
  // Total count of values in this child's subtree, including the child.
  1: i64 size;
  // The actual child
  2: ShardedMapChild child;
} (rust.exhaustive)

// This represents either an inlined sharded map node, or an id of
// a node to be loaded from the blobstore.
union ShardedMapChild {
  1: ShardedMapNode inlined;
  2: id.ShardedMapNodeId id;
}

// A binary -> binary map that may be stored sharded in many different nodes.
//
// The final key/values of the map can be defined recursively as so:
// - If the map node is a terminal node, then we store all key/values directly
// within `values`.
// - If the map node is an intermediate node, then for each (byte, map) item of
// its `children` (where `map` may be stored inlined or as an id on the blobstore),
// prepend its keys with the single `byte` and then prepend them again with the `prefix`.
// If `value` is non-null, add a new key to the final map with key equal to `prefix`.
//
// For example, let's look at a concrete example, taking some liberties with notation:
// ShardedMapIntermediateNode {
//   prefix: "foo",
//   value: 12,
//   children: {
//     "b": ShardedMapTerminalNode {
//       values: {
//         "ar": 51,
//         "az": 69,
//       }
//     }
//   }
// }
//
// The "unsharded version" of this map is: {
//   "foo": 12,
//   "foobar": 51,
//   "foobaz": 69,
// }
//
// The representation of the sharded map doesn't make any assumptions about how the
// insertion/removal logic will actually shard the nodes, and any read operations
// should not as well, to ensure maximum compatibility with algorithm design changes.
union ShardedMapNode {
  1: ShardedMapIntermediateNode intermediate;
  2: ShardedMapTerminalNode terminal;
}

const i32 SHARDED_MAP_V2_WEIGHT_LIMIT = 2000;

typedef data.LargeBinary ShardedMapV2Value
typedef data.LargeBinary ShardedMapV2RollupData

struct ShardedMapV2StoredNode {
  1: id.ShardedMapV2NodeId id;
  2: i64 weight;
  3: i64 size;
  4: ShardedMapV2RollupData rollup_data;
} (rust.exhaustive)

union LoadableShardedMapV2Node {
  1: ShardedMapV2Node inlined;
  2: ShardedMapV2StoredNode stored;
}

// ShardedMapV2 is the same as ShardedMap except that it doesn't compress
// small subtrees into terminal nodes, instead it relies purely on inlining
// to solve the problem of having too many small blobs.
//
// Each ShardedMapV2Node has a conceptual weight which is defined as the sum of
// weights of all its inlined children, plus the count of its non-inlined children,
// plus one if it contains a value itself.
//
// To figure out which of a node's children are going to be inlined and which will
// not:
//    1) Recursively figure out inlining for each child's subtree.
//    2) Assume that all children are going to not be inlined and calculate the weight.
//    3) Iterate over children in order and for each check if inlining them will not make
//    the weight of the node go beyond SHARDED_MAP_V2_WEIGHT_LIMIT. If so inline them,
//    otherwise store them in a separate blob and store their id.
//
// This guarantees that the size of individual blobs will not grow too large, and
// should avoid creating too many small blobs in most cases. In particular, subtrees that
// would've have become a terminal node in ShardedMap will all be inlined in ShardedMapV2,
// with the added upside that they could potentially be stored inlined in their parent.
struct ShardedMapV2Node {
  1: data.SmallBinary prefix;
  2: optional ShardedMapV2Value value;
  3: map<byte, LoadableShardedMapV2Node> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) children;
} (rust.exhaustive)

struct DeletedManifestV2 {
  1: optional id.ChangesetId linknode;
  // Map of MPathElement -> DeletedManifestV2Id
  2: ShardedMapNode subentries;
} (rust.exhaustive)

struct BssmFile {} (rust.exhaustive)
struct BssmDirectory {
  1: id.BasenameSuffixSkeletonManifestId id;
  // Number of entries in this subtree.
  // This doesn't need to be part of the manifest, but we add it here to
  // speed up ordered manifest operations
  2: i64 rollup_count;
} (rust.exhaustive)

union BssmEntry {
  1: BssmFile file;
  2: BssmDirectory directory;
} (rust.exhaustive)

// Basename suffix manifest stores file trees in a way that allows fast filtering
// based on suffix of basenames as well as directory prefix of root.
// See docs/basename_suffix_skeleton_manifest.md for more documentation on this.
struct BasenameSuffixSkeletonManifest {
  // Map of MPathElement -> BssmEntry
  1: ShardedMapNode subentries;
} (rust.exhaustive)

// BssmV3 is an optimized version of Bssm that differs from it in two ways:
//
// 1) It uses ShardedMapV2 instead of ShardedMap which avoids creating un-cachable blobs,
// instead dividing the manifest into closely sized blobs.
//
// 2) Stores the sharded map inlined without a layer of indirection, and relies only
// on the sharded map to decide which parts of the manifest should be inlined and
// which should be stored in a separate blob. This avoids the large number of tiny
// blobs that Bssm creates due to how unique basenames tend to be.
struct BssmV3File {} (rust.exhaustive)
struct BssmV3Directory {
  1: ShardedMapV2Node subentries;
} (rust.exhaustive)

union BssmV3Entry {
  1: BssmV3File file;
  2: BssmV3Directory directory;
} (rust.exhaustive)

// TestManifest is a manifest type intended only to be used in tests. It contains
// only the file names and the maximum basename length of all files in each directory.
struct TestManifestFile {} (rust.exhaustive)
struct TestManifestDirectory {
  1: id.TestManifestId id;
  2: i64 max_basename_length;
} (rust.exhaustive)

union TestManifestEntry {
  1: TestManifestFile file;
  2: TestManifestDirectory directory;
} (rust.exhaustive)

struct TestManifest {
  1: map<path.MPathElement, TestManifestEntry> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) subentries;
} (rust.exhaustive)

// TestShardedManifest is a sharded version of TestManifest (uses ShardedMapV2 in place of SortedVectorMap).
struct TestShardedManifestFile {
  // Storing the basename length of the file instead of calculating it from the edges from its parent
  // simplifies the derivation logic.
  1: i64 basename_length;
} (rust.exhaustive)
struct TestShardedManifestDirectory {
  1: id.TestShardedManifestId id;
  2: i64 max_basename_length;
} (rust.exhaustive)

union TestShardedManifestEntry {
  1: TestShardedManifestFile file;
  2: TestShardedManifestDirectory directory;
} (rust.exhaustive)

struct TestShardedManifest {
  1: ShardedMapV2Node subentries;
} (rust.exhaustive)

struct FsnodeFile {
  1: id.ContentId content_id;
  2: bonsai.FileType file_type;
  // size is a u64 stored as an i64
  3: i64 size;
  4: id.Sha1 content_sha1;
  5: id.Sha256 content_sha256;
} (rust.exhaustive)

struct FsnodeDirectory {
  1: id.FsnodeId id;
  2: FsnodeSummary summary;
} (rust.exhaustive)

struct FsnodeSummary {
  1: id.Sha1 simple_format_sha1;
  2: id.Sha256 simple_format_sha256;
  // Counts and sizes are u64s stored as i64s
  3: i64 child_files_count;
  4: i64 child_files_total_size;
  5: i64 child_dirs_count;
  6: i64 descendant_files_count;
  7: i64 descendant_files_total_size;
} (rust.exhaustive)

union FsnodeEntry {
  1: FsnodeFile File;
  2: FsnodeDirectory Directory;
}

// Content-addressed manifest, with metadata useful for filesystem
// implementations.
//
// Fsnodes form a manifest tree, where unique tree content (i.e. the names and
// contents of files and directories, but not their history) is represented by
// a single fsnode.  Fsnode identities change when any file content is changed.
//
// Fsnode metadata includes summary information about the content ID of
// files and manifests, and the number of files and sub-directories within
// directories.
struct Fsnode {
  1: map<path.MPathElement, FsnodeEntry> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) subentries;
  2: FsnodeSummary summary;
} (rust.exhaustive)

struct SkeletonManifestDirectory {
  1: id.SkeletonManifestId id;
  2: SkeletonManifestSummary summary;
} (rust.exhaustive)

struct SkeletonManifestSummary {
  1: i64 child_files_count;
  2: i64 child_dirs_count;
  3: i64 descendant_files_count;
  4: i64 descendant_dirs_count;
  5: i32 max_path_len;
  6: i32 max_path_wchar_len;
  7: bool child_case_conflicts;
  8: bool descendant_case_conflicts;
  9: bool child_non_utf8_filenames;
  10: bool descendant_non_utf8_filenames;
  11: bool child_invalid_windows_filenames;
  12: bool descendant_invalid_windows_filenames;
} (rust.exhaustive)

struct SkeletonManifestEntry {
  // Present if this is a directory, absent for a file.
  1: optional SkeletonManifestDirectory directory;
} (rust.exhaustive)

// Structure-addressed manifest, with metadata useful for traversing manifest
// trees and determining case conflicts.
//
// Skeleton manifests form a manifest tree, where unique tree structure (i.e.
// the names of files and directories, but not their contents or history) is
// represented by a single skeleton manifest.  Skeleton manifest identities
// change when files are added or removed.
struct SkeletonManifest {
  1: map<path.MPathElement, SkeletonManifestEntry> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) subentries;
  2: SkeletonManifestSummary summary;
} (rust.exhaustive)

// Structure that holds a commit graph, usually a history of a file
// or a directory hence the name. Semantically it stores list of
// (commit hash, [parent commit hashes]), however it's stored in compressed form
// described below. Compressed form is used to save space.
//
// FastlogBatch has two parts: `latest` and `previous_batches`.
// `previous_batches` field points to another FastlogBatch structures so
// FastlogBatch is a recursive structure. However normally `previous_batches`
// point to degenerate version of FastlogBatch with empty `previous_batches`
// i.e. we have only one level of nesting.
//
// In order to get the full list we need to get latest commits and concatenate
// it with lists from `previous_batches`.
//
// `latest` stores commit hashes and offsets to commit parents
// i.e. if offset is 1, then next commit is a parent of a current commit.
// For example, a list like
//
//  (HASH_A, [HASH_B])
//  (HASH_B, [])
//
//  will be encoded as
//  (HASH_A, [1])  # offset is 1, means next hash
//  (HASH_B, [])
//
//  A list with a merge
//  (HASH_A, [HASH_B, HASH_C])
//  (HASH_B, [])
//  (HASH_C, [])
//
//  will be encoded differently
//  (HASH_A, [1, 2])
//  (HASH_B, [])
//  (HASH_C, [])
//
// Note that offset might point to a commit in a next FastlogBatch or even
// point to batch outside of all previous_batches.
struct FastlogBatch {
  1: list<CompressedHashAndParents> latest;
  2: list<id.FastlogBatchId> previous_batches;
} (rust.exhaustive)

typedef i32 ParentOffset (rust.newtype)

struct CompressedHashAndParents {
  1: id.ChangesetId cs_id;
  # Offsets can be negative!
  2: list<ParentOffset> parent_offsets;
} (rust.exhaustive)

typedef i32 BlameChangeset (rust.newtype)
typedef i32 BlamePath (rust.newtype)

enum BlameRejected {
  TooBig = 0,
  Binary = 1,
}

// Blame V1

struct BlameRange {
  1: i32 length;
  2: id.ChangesetId csid;
  3: BlamePath path;
  // offset of this range in the origin file (file that introduced this change)
  4: i32 origin_offset;
} (rust.exhaustive)

struct Blame {
  1: list<BlameRange> ranges;
  2: list<path.NonRootMPath> paths;
} (rust.exhaustive)

union BlameMaybeRejected {
  1: Blame Blame (py3.name = "blame");
  2: BlameRejected Rejected;
}

// Blame V2

struct BlameRangeV2 {
  // Length (in lines) of this range.  The offset of a range is implicit from
  // the sum of the lengths of the prior ranges.
  1: i32 length;

  // Index into csids of the changeset that introduced these lines.
  2: BlameChangeset csid_index;

  // Index into paths of the path of this file when this line was introduced.
  3: BlamePath path_index;

  // The offset of this range at the time that this line was introduced.
  4: i32 origin_offset;

  // "Skip past this change" support.
  //
  // The following fields allows clients to provide an accurate "skip past this
  // change" feature.  From any given range in a blame file, "skip path this
  // change" will direct the user to a *range* of lines in the same file in
  // one of the parents of the changeset that this range is blamed to (i.e.,
  // the changeset specified by `csid_index`).
  //
  // If the range originates in the first version of the file (i.e. this is
  // a root commit for the file), then these fields will not be present.
  //
  // In the simplest case, the target file is the file with the name specified
  // by `path_index` in the first parent of the changeset specified by
  // `csid_index`.
  //
  // The range of lines specified by `parent_offset` and `parent_length`
  // corresponds to the lines that were *replaced* by this range.  In the case
  // of pure insertions, `parent_length` will be 0, indicating that the new
  // lines were *inserted* before the line at `parent_offset`.
  //
  // If the file was renamed during this change, then `renamed_from_path_index`
  // will contain the index into paths of the name of the file before the rename.
  // This should be used in preference to `path_index` to find the target file.
  //
  // If the target commit was a merge commit, and the file was not present in
  // the first parent, then `parent_index` will contain the index (in the list
  // of parents in the bonsai changeset) of the first parent that does contain
  // the file.
  //
  // Thus, the algorithm for finding the destination for "skip past this change"
  // is:
  //
  //  1. Look up `csid_index` in `csids` to find the blamed changeset, and load
  //     its BonsaiChangeset.
  //  2. Find the parent at `parent_index` in the list of parents, or the first
  //     parent if `parent_index` is not present.  This is the target changeset.
  //  3. Look up the path at `renamed_from_path_index` in `paths`, or
  //     `path_index` if `renamed_from_path_index` is not present.  This is the
  //     target path.
  //  4. Load the file at the target path in the target changeset.
  //  5. Jump to the range of lines of length `parent_length` starting at
  //     `parent_offset`.  This is the range of lines that were changed by the
  //     change we are skipping over.  Note that the length might be 0,
  //     indicating an insertion.

  // The offset of this range in the file before this range was introduced that
  // was replaced by this range.  Not present for root commits.
  5: optional i32 parent_offset;

  // The length of the range in the file before this range was introduced that
  // was replaced by this range.  Not present for root commits.
  6: optional i32 parent_length;

  // If this file was being renamed when this line was introduced, this is
  // the index into paths of the original path.  Not present for root commits
  // or if the file has the same name as path_index.
  7: optional BlamePath renamed_from_path_index;

  // If this is a merge commit, and the file is not in the first parent, then
  // this is the index of the first parent that contains the file that contains
  // the range that this range replaces.
  //
  // Not present for ranges in root commits or commits with single parents, or
  // if the file is present in the first parent.
  //
  // Note that this is an index into the list of parents in the bonsai
  // changeset, and *not* an index into csids.
  8: optional i32 parent_index;
} (rust.exhaustive)

struct BlameDataV2 {
  // A list of ranges that describe when the lines of this file were
  // introduced.
  1: list<BlameRangeV2> ranges;

  // A mapping of integer indexes to changeset IDs that is used to reduce the
  // repetition of data in ranges.
  //
  // Changeset ID indexes are stable for p1 parents, i.e. a changeset ID's
  // index will not change over the history of a file unless the file is merged
  // in a changeset, in which case only the indexes in the first parent of the
  // changeset are preserved.

  // Changesets are removed from this map when all lines that were added in the
  // changeset are moved and none of the ranges reference it.  This means there
  // are gaps in this mapping, and so a map is used.
  2: map<i32, id.ChangesetId> (
    rust.type = "sorted_vector_map::SortedVectorMap",
  ) csids;

  // The maximum index that is assigned to a changeset id.  This is also the
  // index that would be assigned to the current changeset, as long as the
  // changeset adds new lines.  If the changeset only deletes or merges lines,
  // then this index will not appear in the csids map.
  3: BlameChangeset max_csid_index;

  // The list of paths that this file has been located at.  This is used to
  // reduce repetition of data in ranges.  Since files are not often moved, and
  // for simplicity, this includes all paths the file has ever been located at,
  // even if they are no longer referenced by any of the ranges.
  4: list<path.NonRootMPath> paths;
} (rust.exhaustive)

union BlameV2 {
  // This version of the file contains full blame information.
  1: BlameDataV2 full_blame;

  // This version of the file was rejected for blaming.
  2: BlameRejected rejected;
}

struct RedactionKeyList {
  // List of keys to be redacted
  1: list<string> keys;
} (rust.exhaustive)
