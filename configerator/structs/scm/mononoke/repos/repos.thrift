// @generated SignedSource<<b7ce29c07d352a6a355550ed3d9c747d>>
// DO NOT EDIT THIS FILE MANUALLY!
// This file is a mechanical copy of the version in the configerator repo. To
// modify it, edit the copy in the configerator repo instead and copy it over by
// running the following in your fbcode directory:
//
// configerator-thrift-updater scm/mononoke/repos/repos.thrift
/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

include "thrift/annotation/rust.thrift"

namespace py configerator.mononoke.repos
namespace py3 mononoke.repos

// After editing, run `fbpython source/pyre/scripts/generate_stubs.py source/scm/mononoke/repos/repos.thrift`

// NOTICE:
// Don't use 'defaults' for any of these values (e.g. 'bool enabled = true')
// because these structs will be deserialized by serde in rust. The following
// rules apply upon deserialization:
//   1) specified default values are ignored, default values will always be
//      the 'Default::default()' value for a given type. For example, even
//      if you specify:
//          1: bool enabled = true,
//
//       upon decoding, if the field enabled isn't present, the default value
//       will be false.
//
//   2) not specifying optional won't actually make your field required,
//      neither will specifying required make any field required. Upon decoding
//      with serde, all values will be Default::default() and no error will be
//      given.
//
//   3) the only way to detect wether a field was specified in the structure
//      being deserialized is by making a field optional. This will result in
//      a 'None' value for a Option<T> in rust. So the way we can give default
//      values other then 'Default::default()' is by making a field optional,
//      and then explicitly handle 'None' after deserialization.

@rust.Exhaustive
struct RawRepoConfigs {
  1: map_string_RawCommitSyncConfig_4989 commit_sync;
  2: RawCommonConfig common;
  3: map_string_RawRepoConfig_815 repos; # to be renamed to repo_configs
  4: map_string_RawStorageConfig_2830 storage; # to be renamed to storage_configs
  6: map_string_RawAclRegionConfig_3881 acl_region_configs;
  5: RawRepoDefinitions repo_definitions;
}

@rust.Exhaustive
struct RawRepoDefinitions {
  // map from repo_name to a simple structure containing repo-specific data like
  // repo_id or repo_name that can be used at runtime whenever RawRepoConfig
  // needs it.
  1: map_string_RawRepoDefinition_9793 repo_definitions;
}

@rust.Exhaustive
struct RawRepoDefinition {
  // Most important - the unique ID of this Repo
  // Required - don't let the optional comment fool you, see notice above.
  1: optional i32 repo_id;

  2: optional string repo_name;

  // In case this repo is related with some other repo in other id namespace.
  3: optional i32 external_repo_id;

  // Key into RawRepoConfigs.repos
  4: optional string repo_config;

  // 5: deleted

  // Name of the ACL used for this repo.
  6: optional string hipster_acl;

  // Repo is enabled for use.
  7: optional bool enabled;

  // Repo is read-only (default false).
  8: optional bool readonly;

  // Should this repo be backed up?
  9: optional bool needs_backup;

  // In case this is a backup repo, what's the origin repo name?
  10: optional string backup_source_repo_name;

  // Key into RawRepoConfigs.acl_region_configs for the definition of
  // ACL regions for this repo.
  11: optional string acl_region_config;

  // Default hashing scheme used for revisions given by clients
  // when they interact with the repo without specifying this explicitly.
  12: optional RawCommitIdentityScheme default_commit_identity_scheme;
}

// The schemes by which commits can be identified.
enum RawCommitIdentityScheme {
  UNKNOWN = 0,
  /// Commits are identified by the 32-byte hash of Mononoke's bonsai
  /// changeset.
  BONSAI = 1,

  /// Commits are identified by the 20-byte hash of the Mercurial commit.
  HG = 2,

  /// Commits are identified by the 20-byte hash of the Git commit.
  GIT = 3,
}

@rust.Exhaustive
struct RawRepoConfig {
  // Persistent storage - contains location of metadata DB and name of
  // blobstore we're using. We reference the common storage config by name.
  // Required - don't let the optional comment fool you, see notice above
  2: optional string storage_config;

  // Local definitions of storage (override the global defined storage)
  3: optional map<string, RawStorageConfig> storage;

  // Define special bookmarks with parameters
  6: optional list<RawBookmarkConfig> bookmarks;
  7: optional i64 bookmarks_cache_ttl;

  // Define hook manager
  8: optional RawHookManagerParams hook_manager_params;

  // Define hook available for use on bookmarks
  9: optional list<RawHookConfig> hooks;

  // This enables or disables verification for censored blobstores
  11: optional bool redaction;

  12: optional i64 generation_cache_size;
  13: optional string scuba_table;
  14: optional string scuba_table_hooks;
  15: optional i64 delay_mean;
  16: optional i64 delay_stddev;
  17: optional RawCacheWarmupConfig cache_warmup;
  18: optional RawPushParams push;
  19: optional RawPushrebaseParams pushrebase;
  20: optional RawLfsParams lfs;
  22: optional i64 hash_validation_percentage;
  // 23: deleted
  24: optional RawBundle2ReplayParams bundle2_replay_params;
  25: optional RawInfinitepushParams infinitepush;
  26: optional i64 list_keys_patterns_max;
  27: optional RawFilestoreParams filestore;
  28: optional i64 hook_max_file_size;
  31: optional RawSourceControlServiceParams source_control_service;
  30: optional RawSourceControlServiceMonitoring source_control_service_monitoring;
  // Types of derived data that are derived for this repo and are safe to use
  33: optional RawDerivedDataConfig derived_data_config;

  // Log Scuba samples to files. Largely only useful in tests.
  34: optional string scuba_local_path;
  35: optional string scuba_local_path_hooks;
  // 36: deleted
  // 37: deleted
  38: optional RawSegmentedChangelogConfig segmented_changelog_config;
  39: optional bool enforce_lfs_acl_check;
  // Use warm bookmark cache while serving data hg wireprotocol
  40: optional bool repo_client_use_warm_bookmarks_cache;
  // Deprecated
  41: optional bool warm_bookmark_cache_check_blobimport;
  // A collection of knobs to enable/disable functionality in repo_client module
  42: optional RawRepoClientKnobs repo_client_knobs;
  43: optional string phabricator_callsign;
  // Define parameters for backups jobs
  44: optional RawBackupRepoConfig backup_config;
  // Define parameters for repo scrub/walker jobs
  45: optional RawWalkerConfig walker_config;
  // Cross-repo commit validation config
  46: optional RawCrossRepoCommitValidationConfig cross_repo_commit_validation_config;
  // Configuration related to the sparse profiles
  47: optional RawSparseProfilesConfig sparse_profiles_config;
  // Configuration related to hg-sync job for prod repos
  48: optional RawHgSyncConfig hg_sync_config;
  // Configuration related to hg-sync job for backup repos
  49: optional RawHgSyncConfig backup_hg_sync_config;
  // 50: deleted
  // The scribe category to use for logging bookmark updates
  // (NOTE: will be replaced by update_logging_config.bookmark_logging_destination)
  51: optional string bookmark_scribe_category;
  // Configuration for logging of repo updates.
  52: optional RawUpdateLoggingConfig update_logging_config;
  // Configuration for the commit graph
  53: optional RawCommitGraphConfig commit_graph_config;
  // Configuration for deep sharding mode.
  // shallow-sharded: Requests are sharded but repo is on every server
  // deep-sharded: In addition to requests, repo is also sharded, i.e. present
  // on select servers.
  54: optional RawShardingModeConfig deep_sharding_config;
  // Everstore local path. Largely only userful in tests.
  55: optional string everstore_local_path;
  // The concurrency setting to be used during git protocol for this repo
  56: optional RawGitConcurrencyParams git_concurrency;
  // Configuration for the repo metadata logger
  57: optional RawMetadataLoggerConfig metadata_logger_config;
  // Configuration for connecting to Zelos
  58: optional RawZelosConfig zelos_config;
}

// Configuration for connecting to Zelos
union RawZelosConfig {
  // Connect to a local Zelos server running on this port
  1: i64 local_zelos_port;
  // Connect to a remote Zelos tier
  2: string zelos_tier;
}

// The concurrency setting to be used during git protocol
@rust.Exhaustive
struct RawGitConcurrencyParams {
  // The concurrency value for tree and blob fetches
  1: i64 trees_and_blobs;
  // The concurrency value for commit fetches
  2: i64 commits;
  // The concurrency value for tag fetches
  3: i64 tags;
}

// Config determining if deep sharding mode is enabled for a service.
@rust.Exhaustive
struct RawShardingModeConfig {
  1: map<RawShardedService, bool> status;
}

// Mononoke services for which sharding can be enabled.
enum RawShardedService {
  UNKNOWN = 0,
  EDEN_API = 1,
  SOURCE_CONTROL_SERVICE = 2,
  DERIVED_DATA_SERVICE = 3,
  LAND_SERVICE = 4,
  DERIVATION_WORKER = 5,
  LARGE_FILES_SERVICE = 6,
  ASYNC_REQUESTS_WORKER = 7,
  WALKER_SCRUB_ALL = 8,
  WALKER_VALIDATE_ALL = 9,
  HG_SYNC = 10,
  HG_SYNC_BACKUP = 11,
  DERIVED_DATA_TAILER = 12,
  ALIAS_VERIFY = 13,
  DRAFT_COMMIT_DELETION = 14,
  MONONOKE_GIT_SERVER = 15,
  REPO_METADATA_LOGGER = 16,
}

@rust.Exhaustive
struct RawWalkerConfig {
  // Controls if scrub of data into history is enabled
  1: bool scrub_enabled;
  // Controls if validation of shallow walk from master enabled
  2: bool validate_enabled;
  // Controls non-standard parameter values for different walker
  // job types
  3: optional map<RawWalkerJobType, RawWalkerJobParams> params;
}

/// Repo-specific configuration parameters for hg sync job
/// Parameters for a specific hg sync job variant
struct RawHgSyncConfig {
  /// Remote path to hg repo to replay to
  1: string hg_repo_ssh_path;
  /// Maximum number of bundles allowed over a single hg peer
  2: i64 batch_size;
  /// If set, Mononoke repo will be locked on sync failure
  3: bool lock_on_failure;
  /// The darkstorm backup repo-id to be used as target for sync
  4: optional i32 darkstorm_backup_repo_id;
}

struct RawWalkerJobParams {
  // Controls max concurrency for MySQL and other dependencies
  1: optional i64 scheduled_max_concurrency;
  // Controls the max blobstore read QPS for a given repo
  2: optional i64 qps_limit;
  // The type of nodes to be excluded during walk
  3: optional string exclude_node_type;
  // Whether to allow remaining deferred edges after chunks complete.
  4: optional bool allow_remaining_deferred;
  // Control whether walker continues in the face of error for specified
  // node types
  5: optional string error_as_node_data_type;
}

/// The type of walker jobs deployed in production
enum RawWalkerJobType {
  UNKNOWN = 0,
  VALIDATE_ALL = 1,
  SCRUB_ALL_CHUNKED = 2,
  SCRUB_HG_ALL_CHUNKED = 3,
  SCRUB_HG_FILE_CONTENT = 4,
  SCRUB_HG_FILE_NODE = 5,
  SCRUB_UNODE_ALL_CHUNKED = 6,
  SCRUB_UNODE_BLAME = 7,
  SCRUB_DERIVED_NO_CONTENT_META = 8,
  SCRUB_DERIVED_NO_CONTENT_META_CHUNKED = 9,
  SCRUB_UNODE_FASTLOG = 10,
  SCRUB_DERIVED_CHUNKED = 11,
  SHALLOW_HG_SCRUB = 12,
}

@rust.Exhaustive
struct RawBackupRepoConfig {
  // Enable backup verification job for this repo
  2: bool verification_enabled;
}

@rust.Exhaustive
struct RawRepoClientKnobs {
  1: bool allow_short_getpack_history;
}

@rust.Exhaustive
struct RawDerivedDataConfig {
  1: optional string scuba_table;
  // 2: deleted
  // 3: deleted
  // 4: deleted
  5: optional RawDerivedDataTypesConfig enabled; // deprecated
  6: optional RawDerivedDataTypesConfig backfilling; // deprecated
  7: optional map<string, RawDerivedDataTypesConfig> available_configs;
  8: optional string enabled_config_name;
}

@rust.Exhaustive
struct RawDerivedDataTypesConfig {
  1: set<string> types;
  6: map<string, string> mapping_key_prefixes;
  2: optional i16 unode_version;
  3: optional i64 blame_filesize_limit;
  4: optional bool hg_set_committer_extra;
  5: optional i16 blame_version;
  // 7. deleted
  8: optional i16 git_delta_manifest_version;
}

@rust.Exhaustive
struct RawBlobstoreDisabled {}
@rust.Exhaustive
struct RawBlobstoreFilePath {
  1: string path;
}
@rust.Exhaustive
struct RawBlobstoreManifold {
  1: string manifold_bucket;
  2: string manifold_prefix;
}
@rust.Exhaustive
struct RawBlobstoreMysql {
  // 1: deleted
  // 2: deleted
  3: RawDbShardableRemote remote;
}
// See docs in fbcode/eden/mononoke/metaconfig/types/src/lib.rs:BlobConfig::MultiplexedWal
@rust.Exhaustive
struct RawBlobstoreMultiplexedWal {
  1: i32 multiplex_id;
  2: list<RawBlobstoreIdConfig> components;
  3: i64 write_quorum;
  4: RawShardedDbConfig queue_db;
  // The scuba table to log stats per underlying blobstore
  5: optional string inner_blobstores_scuba_table;
  // The scuba table to log stats for the overall multiplex
  6: optional string multiplex_scuba_table;
  // Used for both scuba tables. Write queries and read failures are not sampled.
  7: optional i64 scuba_sample_rate;
}
@rust.Exhaustive
struct RawBlobstoreManifoldWithTtl {
  1: string manifold_bucket;
  2: string manifold_prefix;
  3: i64 ttl_secs;
}
@rust.Exhaustive
struct RawBlobstoreLogging {
  1: optional string scuba_table;
  2: optional i64 scuba_sample_rate;
  @rust.Box
  3: RawBlobstoreConfig blobstore;
}
@rust.Exhaustive
struct RawBlobstorePackRawFormat {}
@rust.Exhaustive
struct RawBlobstorePackZstdFormat {
  1: i32 compression_level;
}
union RawBlobstorePackFormat {
  1: RawBlobstorePackRawFormat Raw;
  2: RawBlobstorePackZstdFormat ZstdIndividual;
}
@rust.Exhaustive
struct RawBlobstorePackConfig {
  1: RawBlobstorePackFormat put_format;
}
@rust.Exhaustive
struct RawBlobstorePack {
  @rust.Box
  1: RawBlobstoreConfig blobstore;
  2: optional RawBlobstorePackConfig pack_config;
}
@rust.Exhaustive
struct RawBlobstoreS3 {
  1: string bucket;
  2: string keychain_group;
  3: string region_name;
  4: string endpoint;
  // Limit the number of concurrent operations to S3
  // blobstore.
  5: optional i32 num_concurrent_operations;
  // Name of the secret within the group
  6: optional string secret_name;
}
@rust.Exhaustive
struct RawBlobstoreAwsS3 {
  1: string aws_account_id;
  2: string aws_role;
  3: string bucket;
  4: string region;
  // Limit the number of concurrent operations to S3
  // blobstore.
  5: optional i32 num_concurrent_operations;
}

// Configuration for a single blobstore. These are intended to be defined in a
// separate blobstore.toml config file, and then referenced by name from a
// per-server config. Names are only necessary for blobstores which are going
// to be used by a server. The id field identifies the blobstore as part of a
// multiplex, and need not be defined otherwise. However, once it has been set
// for a blobstore, it must remain unchanged.
union RawBlobstoreConfig {
  1: RawBlobstoreDisabled disabled;
  2: RawBlobstoreFilePath blob_files;
  // 3: deleted
  4: RawBlobstoreFilePath blob_sqlite;
  5: RawBlobstoreManifold manifold;
  6: RawBlobstoreMysql mysql;
  // 7: deleted
  8: RawBlobstoreManifoldWithTtl manifold_with_ttl;
  9: RawBlobstoreLogging logging;
  10: RawBlobstorePack pack;
  11: RawBlobstoreS3 s3;
  12: RawBlobstoreMultiplexedWal multiplexed_wal;
  13: RawBlobstoreAwsS3 aws_s3;
}

// A write-only blobstore is one that is not read from in normal operation.
// Mononoke will read from it in these cases:
// 1. Verifying that data is present in all blobstores (scrub etc)
union RawMultiplexedStoreType {
  1: RawMultiplexedStoreNormal normal;
  // 2: deleted
  3: RawMultiplexedStoreWriteOnly write_only;
}

@rust.Exhaustive
struct RawMultiplexedStoreNormal {}
@rust.Exhaustive
struct RawMultiplexedStoreWriteOnly {}

@rust.Exhaustive
struct RawBlobstoreIdConfig {
  1: i64 blobstore_id;
  2: RawBlobstoreConfig blobstore;
  3: optional RawMultiplexedStoreType store_type;
}

@rust.Exhaustive
struct RawDbLocal {
  1: string local_db_path;
}

@rust.Exhaustive
struct RawDbRemote {
  1: string db_address;
// 2: deleted
}

@rust.Exhaustive
struct RawOssDbRemote {
  1: string host;
  2: i16 port;
  // 3: deleted
  // 4: deleted
  5: string database;
  // 6: deleted
  7: string password_secret;
  8: string user_secret;
}

@rust.Exhaustive
struct RawDbShardedRemote {
  1: string shard_map;
  2: i32 shard_num;
}

union RawDbShardableRemote {
  1: RawDbRemote unsharded;
  2: RawDbShardedRemote sharded;
}

union RawDbConfig {
  1: RawDbLocal local;
  2: RawDbRemote remote;
}

union RawShardedDbConfig {
  1: RawDbLocal local;
  2: RawDbShardedRemote remote;
  3: RawDbRemote unsharded;
}

@rust.Exhaustive
struct RawRemoteMetadataConfig {
  1: RawDbRemote primary;
  2: RawDbShardableRemote filenodes;
  3: RawDbRemote mutation;
  4: RawDbRemote sparse_profiles;
  5: optional RawDbShardableRemote bonsai_blob_mapping;
  6: optional RawDbRemote deletion_log;
  7: optional RawDbRemote commit_cloud;
}

@rust.Exhaustive
struct RawOssRemoteMetadataConfig {
  1: RawOssDbRemote primary;
  2: RawOssDbRemote filenodes;
  3: RawOssDbRemote mutation;
  4: RawOssDbRemote sparse_profiles;
  5: optional RawOssDbRemote bonsai_blob_mapping;
  6: optional RawOssDbRemote deletion_log;
}

union RawMetadataConfig {
  1: RawDbLocal local;
  2: RawRemoteMetadataConfig remote;
  3: RawOssRemoteMetadataConfig oss_remote;
}

enum RawBubbleDeletionMode {
  DISABLED = 0,
  MARK_ONLY = 1,
  MARK_AND_DELETE = 2,
}

@rust.Exhaustive
struct RawEphemeralBlobstoreConfig {
  1: RawBlobstoreConfig blobstore;
  2: RawDbConfig metadata;
  4: i64 initial_bubble_lifespan_secs;
  5: i64 bubble_expiration_grace_secs;
  6: RawBubbleDeletionMode bubble_deletion_mode;
}

@rust.Exhaustive
struct RawStorageConfig {
  // 1: deleted
  3: RawMetadataConfig metadata;
  2: RawBlobstoreConfig blobstore;
  4: optional RawEphemeralBlobstoreConfig ephemeral_blobstore;
}

@rust.Exhaustive
struct RawPushParams {
  1: optional bool pure_push_allowed;
  // 2: deleted
  /// The maximum number of commits that will be accepted in a single unbundle request
  3: optional i64 unbundle_commit_limit;
}

@rust.Exhaustive
struct RawPushrebaseRemoteModeLocal {}
union RawPushrebaseRemoteModeRemote {
  1: string tier;
  2: string host_port;
}

union RawPushrebaseRemoteMode {
  1: RawPushrebaseRemoteModeLocal local;
  // 2: deleted
  // 3: deleted
  4: RawPushrebaseRemoteModeRemote remote_land_service;
  5: RawPushrebaseRemoteModeRemote remote_land_service_local_fallback;
}

@rust.Exhaustive
struct RawPushrebaseParams {
  1: optional bool rewritedates;
  2: optional i64 recursion_limit;
  // 3: deleted
  4: optional bool block_merges;
  5: optional bool forbid_p2_root_rebases;
  6: optional bool casefolding_check;
  7: optional bool emit_obsmarkers;
  // 8: deleted
  9: optional bool populate_git_mapping;
  // A bookmark that assigns globalrevs. This bookmark can only be pushed to
  // via pushrebase. Other bookmarks can only be pushed to commits that are
  // ancestors of this bookmark.
  10: optional string globalrevs_publishing_bookmark;
  // For the case when one repo is linked to another (a.k.a. megarepo)
  // there's a special commit extra that allows changing the mapping
  // used to rewrite a commit from one repo to another.
  // Normally pushes of a commit like this are not allowed unless
  // this option is set to false.
  11: optional bool allow_change_xrepo_mapping_extra;
  // How to do pushrebase from Mononoke, remotely or local.
  12: optional RawPushrebaseRemoteMode remote_mode;
  // Pushes to which bookmark should be logged to ODS for monitoring
  // This will usually be the "main bookmark" of the repo
  13: optional string monitoring_bookmark;
  // If assigning globalrevs on a large repo, only do it if the
  // small repo is pushredirected.
  14: optional i32 globalrevs_small_repo_id;
  // Case conflicts in those paths will be ignored
  15: optional list<string> casefolding_check_excluded_paths;
}

@rust.Exhaustive
struct RawBookmarkConfig {
  // Either the regex or the name should be provided, not both
  1: optional string regex;
  2: optional string name;
  3: list<RawBookmarkHook> hooks;
  // Are non fastforward moves allowed for this bookmark
  4: bool only_fast_forward;

  // If specified, and if the user's unixname is known, only users who
  // belong to this group or match allowed_users will be allowed to move this
  // bookmark.
  5: optional string allowed_users;

  // If specified, and if the user's unixname is known, only users who
  // belong to this group or match allowed_users will be allowed to move this
  // bookmark.
  9: optional string allowed_hipster_group;

  // Deprecated
  8: optional bool allow_only_external_sync;

  // Whether or not to rewrite dates when processing pushrebase pushes
  6: optional bool rewrite_dates;

  // Other bookmarks whose ancestors are skipped when running hooks
  //
  // This is used during plain bookmark pushes and other simple bookmark
  // updates to avoid running hooks on commits that have already passed the
  // hook.
  //
  // For example, if this field contains "master", and we move a release
  // bookmark like this:
  //
  //   o master
  //   :
  //   : o new
  //   :/
  //   o B
  //   :
  //   : o old
  //   :/
  //   o A
  //   :
  //
  // then changesets in the range A::B will be skipped by virtue of being
  // ancestors of master, which should mean they have already passed the
  // hook.
  7: optional list<string> hooks_skip_ancestors_of;

  // Ensure that given bookmark(s) are ancestors of `ensure_ancestor_of`
  // bookmark. That also implies that it's not longer possible to
  // pushrebase to these bookmarks.
  10: optional string ensure_ancestor_of;

  // This option allows moving a bookmark to a commit that's already
  // public while bypassing all the hooks. Note that should be fine,
  // because commit is already public, meaning that hooks already
  // should have been run when the commit was first made public.
  11: optional bool allow_move_to_public_commits_without_hooks;
}

@rust.Exhaustive
struct RawAllowlistIdentity {
  1: string identity_type;
  2: string identity_data;
}

@rust.Exhaustive
struct RawMononokeAcls {
  1: map<string, RawMononokeAcl> repos;
  2: map<string, RawMononokeAcl> repo_regions;
  3: map<string, RawMononokeAcl> tiers;
  4: map<string, list<list<string>>> groups;
}

@rust.Exhaustive
struct RawMononokeAcl {
  1: map<string, list<string>> actions;
}

@rust.Exhaustive
struct RawRedactionConfig {
  // Blobstore config for redaction config, indexed by name
  1: string blobstore;
  // Blobstore used to store backup of the redaction config, usually
  // darkstorm. Only used on admin command that creates the config.
  2: optional string darkstorm_blobstore;
  // Configerator path where RedactionSets are
  // TODO: Once the whole config is hot reloadable, move redaction
  // sets inside this struct instead
  3: string redaction_sets_location;
}

@rust.Exhaustive
struct RawCommonConfig {
  // 1: deleted

  2: optional string loadlimiter_category;

  // Scuba table for logging redacted file access attempts
  3: optional string scuba_censored_table;
  // Local file to log redacted file accesses to (useful in tests).
  4: optional string scuba_local_path_censored;

  // Whether to enable the control API over HTTP. At this time, this is
  // only meant to be used in tests.
  5: bool enable_http_control_api;

  6: RawRedactionConfig redaction_config;

  // Hipster tier name containing entities that are permitted to act as
  // trusted proxies.  Mononoke will accept and use proxied authentication
  // data from entities that pass the `trusted_parties` action for this tier.
  7: optional string trusted_parties_hipster_tier;

  // List of identities that are permitted to act as trusted proxies.
  // Mononoke will accept and use proxied authentication data from these
  // entities in lieu of their own identities.
  8: optional list<RawAllowlistIdentity> trusted_parties_allowlist;

  // List of identities that are allowlisted globally, and can always access
  // all repos.
  9: optional list<RawAllowlistIdentity> global_allowlist;

  // Identity for internal Mononoke services. Requests from these services
  // can be trusted to not have been done directly by users.
  10: RawAllowlistIdentity internal_identity;

  // Upper bound in bytes for the RSS memory that can be utilized by Mononoke GRit
  // server for serving packfile stream
  11: optional i64 git_memory_upper_bound;

  // Scuba table to dump edenapi requests to (for replay)
  12: optional string edenapi_dumper_scuba_table;
}

@rust.Exhaustive
struct RawCacheWarmupConfig {
  1: string bookmark;
  2: optional i64 commit_limit;
  3: optional bool microwave_preload;
}

@rust.Exhaustive
struct RawBookmarkHook {
  1: string hook_name;
}

@rust.Exhaustive
struct RawHookManagerParams {
  /// Wether to disable the acl checker or not (intended for testing purposes)
  1: bool disable_acl_checker;
  2: bool all_hooks_bypassed;
  3: optional string bypassed_commits_scuba_table;
}

@rust.Exhaustive
struct RawHookConfig {
  /// Name of this hook.  This is the name that will appear in error messages.
  1: string name;

  /// Name of the hook implementation.  If missing, the hook name is used.
  2: optional string implementation;

  /// Configuration options in JSON format.  Check the implementation to see
  /// what values are allowed or expected.
  3: optional string config_json;

  /// String which, when present in the commit message, bypasses the hook.
  4: optional string bypass_commit_string;

  /// Pushvar (name=value), which when present in the push, bypasses the hook.
  5: optional string bypass_pushvar;

  // The remaining config options are deprecated.  Use `config_json` instead.

  6: optional map_string_string_6987 config_strings;
  7: optional map_string_i32_6602 config_ints;
  8: optional map_string_list_string_6265 config_string_lists;
  9: optional map_string_list_i32_8462 config_int_lists;
  10: optional map_string_i64_6128 config_ints_64;
  11: optional map_string_list_i64_8629 config_int_64_lists;
}

@rust.Exhaustive
struct RawLfsParams {
  1: optional i64 threshold;
  // What percentage of client host gets lfs pointers
  2: optional i32 rollout_percentage;
  // Whether to generate lfs blobs in hg sync job
  3: optional bool generate_lfs_blob_in_hg_sync_job;
// 4: deleted
}

@rust.Exhaustive
struct RawBundle2ReplayParams {
  1: optional bool preserve_raw_bundle2;
}

@rust.Exhaustive
struct RawInfinitepushParams {
  1: bool allow_writes;
  2: optional string namespace_pattern;
  3: optional bool hydrate_getbundle_response;
// 4: deleted
// 5: deleted
// 6: deleted
// 7: deleted
}

@rust.Exhaustive
struct RawFilestoreParams {
  1: i64 chunk_size;
  2: i32 concurrency;
}

// How to handle file changes to git submodules when syncing commits
enum RawGitSubmodulesChangesAction {
  UNKNOWN = 0,
  /// Sync all changes made to git submodules without alterations.
  KEEP = 1,
  /// Strip any changes made to git submodules from the synced bonsai.
  STRIP = 2,
  /// Expand any submodule file change into multiple file changes that
  /// achieve the same working copy. i.e. Copy the contents of the submodule
  /// repo into the synced version of the source repo in the target repo.
  /// This requires the `submodule_dependencies` field to be properly set
  /// in the small repo's sync config.
  EXPAND = 3,
}

@rust.Exhaustive
struct RawCommitSyncSmallRepoConfig {
  1: i32 repoid;
  2: string default_action;
  3: optional string default_prefix;
  4: string bookmark_prefix;
  5: map<string, string> mapping;
  6: string direction;
  7: optional RawGitSubmodulesChangesAction git_submodules_action;
  /// Map from submodule path in the small repo to the ID of the submodule's
  /// repository in Mononoke.
  /// These repos have to be loaded with the small repo before syncing starts,
  /// as file changes from the submodule dependencies might need to be copied.
  8: optional map<string, i32> submodule_dependencies;
  /// Prefix of the metadata file that will store the git hash of the submodule
  /// commit that the expansion corresponds to.
  /// This file will be used to backsync commits from large to small repo that
  /// change the submodule expansion.
  /// This file will always be placed in the same directory where the submodule
  /// is expanded and its name will be `.<PREFIX>-<SUBMODULE_BASENAME>`.
  ///
  /// Example: using the prefix `x-repo-submodule`, a submodule located at
  /// `a/b/foo` would have the metadata file  `a/b/.x-repo-submodule-foo`.
  9: optional string submodule_metadata_file_prefix;

  /// List git commit hashes that are known dangling submodule pointers in the
  /// repo's history, i.e. don't actually exist in the submodule repo it's
  /// supposed to point to.
  /// This can happen after non-fast-forward pushes or accidentally pushing
  /// commits with local submodule pointers.
  ///
  /// The expansion of these commits will contain a single text file informing
  /// that the expansion belongs to a dangling submodule pointer.
  10: optional list<string> dangling_submodule_pointers;
}

@rust.Exhaustive
struct RawCommitSyncConfig {
  1: i32 large_repo_id;
  2: list<string> common_pushrebase_bookmarks;
  3: list<RawCommitSyncSmallRepoConfig> small_repos;
  4: optional string version_name;
}

@rust.Exhaustive
struct RawSourceControlServiceParams {
  // Whether ordinary users can write through the source control service.
  1: bool permit_writes;

  // Whether service users can write through the source control service.
  2: bool permit_service_writes;

  // ACL to use for verifying a caller has write access on behalf of a service.
  3: optional string service_write_hipster_acl;

  // Map from service name to the restrictions that apply for that service.
  4: optional map<
    string,
    RawServiceWriteRestrictions
  > service_write_restrictions;

  // Whether users can create commits without parents.
  5: bool permit_commits_without_parents;
}

@rust.Exhaustive
struct RawServiceWriteRestrictions {
  // The service is permitted to call these methods.
  1: set<string> permitted_methods;

  // The service is permitted to modify files with these path prefixes.
  2: optional set<string> permitted_path_prefixes;

  // The service is permitted to modify these bookmarks.
  3: optional set<string> permitted_bookmarks;

  // The service is permitted to modify bookmarks that match this regex.
  4: optional string permitted_bookmark_regex;
}

// Raw configuration for health monitoring of the
// source-control-as-a-service solutions
@rust.Exhaustive
struct RawSourceControlServiceMonitoring {
  1: list<string> bookmarks_to_report_age;
}

// Raw config item of segmented changelog head configuration
union RawSegmentedChangelogHeadConfig {
  // All public bookmarks. Allows for making exceptions by naming bookmarks to
  // exclude.
  1: list<string> all_public_bookmarks_except;
  2: string bookmark;
  3: string bonsai_changeset;
}

@rust.Exhaustive
struct RawSegmentedChangelogConfig {
  // Whether Segmented Changelog should even be initialized.
  1: optional bool enabled;

  // 2: deleted

  // The bookmark that is followed to construct the Master group of the Dag.
  // Defaults to "master".
  3: optional string master_bookmark;

  // How often the tailer should check for updates to the master_bookmark and
  // perform updates. The tailer is disabled when the period is set to 0.
  4: optional i64 tailer_update_period_secs;

  // By default a mononoke process will look for Dags to load from
  // blobstore.  In tests we may not have prebuilt Dags to load so we have
  // this setting to allow us to skip that step and initialize with an empty
  // Dag.
  // We don't want to set this in production.
  5: optional bool skip_dag_load_at_startup;

  // How often an Dag will be reloaded from saves.
  // The Dag will not reload when the period is set to 0.
  6: optional i64 reload_dag_save_period_secs;

  // How often the in process Dag will check the master bookmark to update
  // itself.  The Dag will not check master when the period is set to 0.
  7: optional i64 update_to_master_bookmark_period_secs;

  // List of bonsai changeset to include in the segmented changelog during reseeding.
  //
  // To explain why we might need `bonsai_changesets_to_include` - say we have a
  // commit graph like this:
  // ```
  //  B <- master
  //  |
  //  A
  //  |
  // ...
  // ```
  // Then we move a master bookmark backwards to A and create a new commit on top
  // (this is a very rare situation, but it might happen during sevs)
  //
  // ```
  //  C <- master
  //  |
  //  |  B
  //  | /
  //  A
  //  |
  // ...
  // ```
  //
  // Clients might have already pulled commit B, and so they assume it's present on
  // the server. However if we reseed segmented changelog then commit B won't be
  // a part of a new reseeded changelog because B is not an ancestor of master anymore.
  // It might lead to problems - clients might fail because server doesn't know about
  // a commit they assume it should know of, and server would do expensive sql requests
  // (see S242328).
  //
  // `bonsai_changesets_to_include` might help with that - if we add `B` to
  // `bonsai_changesets_to_include` then every reseeding would add B and it's
  // ancestors to the reseeded segmented changelog. (default: [])
  8: optional list<string> bonsai_changesets_to_include;
  9: list<RawSegmentedChangelogHeadConfig> heads_to_include;
  // Heads that included in segmented changelog by seeders, tailers and other
  // background but are not updated in in-memory dag by all servers.
  10: list<
    RawSegmentedChangelogHeadConfig
  > extra_heads_to_include_in_background_jobs;
}

// Describe ACL Regions for a repository.
//
// This is a set of rules which define regions of the repository (commits and paths)
@rust.Exhaustive
struct RawAclRegionConfig {
  // List of rules that grant access to regions of the repo.
  1: list<RawAclRegionRule> allow_rules;
// List of regions to which default access to the repository is denied.
// 2: list<RawAclRegion> deny_default_regions, (not yet implemented)
}

@rust.Exhaustive
struct RawAclRegionRule {
  // The name of this region rule.  This is used in error messages and diagnostics.
  1: string name;

  // A list of regions that this rule applies to.
  2: list<RawAclRegion> regions;

  // The hipster ACL that defines who is permitted to access the regions of
  // the repo defined by this rule.
  3: string hipster_acl;
}

// Define a region of the repository, in terms of commits and path prefixes.
//
// The commit range is equivalent to the Mercurial revset
//     descendants(roots) - descendants(heads)
//
// If the roots and heads lists are both empty then this region covers the
// entire repo.
@rust.Exhaustive
struct RawAclRegion {
  // List of roots that begin this region.  Any commit that is a descendant of any
  // root, including the root itself, will be included in the region.  If this
  // list is empty then all commits are included (provided they are not the
  // descendant of a head).
  1: list<string> roots;

  // List of heads that end this region.  Any commit that is a descendant of
  // any head, includin the head itself, will NOT be included in the region.
  // If this list is empty then all commits that are descendants of the roots
  // are included.
  2: list<string> heads;

  // List of path prefixes that apply to this region.  Prefixes are in terms of
  // path elements, so the prefix a/b applies to a/b/c but not a/bb.
  3: list<string> path_prefixes;
}

@rust.Exhaustive
struct RawCrossRepoCommitValidationConfig {
  // A set of bookmarks to skip when doing bookmark validation
  // Validation reads the bookmarks change log, and looks for commits
  // that could have been made public by a bookmark move.
  //
  // By listing a bookmark here, you avoid validating its commits. Useful
  // for bookmarks that are never meant to be checked out - e.g. import bookmarks,
  // where the merge will be validated when it appears under another bookmark
  1: set<string> skip_bookmarks;
}

struct RawSparseProfilesConfig {
  // Location where sparse profiles are stored within the repo
  1: string sparse_profiles_location;
  // Excluded paths and files from monitoring
  // used as glob patterns for pathmatchers
  2: optional list<string> excluded_paths;
  // Exact list of monitored profiles.
  // (Profile name relative to sparse_profiles_location)
  // Takes precedence over excludes. If None - monitors all profiles
  3: optional list<string> monitored_profiles;
}

@rust.Exhaustive
struct RawLoggingDestinationLogger {}

@rust.Exhaustive
struct RawLoggingDestinationScribe {
  // Scribe category to log to
  1: string scribe_category;
}

union RawLoggingDestination {
  // Log to Logger
  1: RawLoggingDestinationLogger logger;
  // Log to a scribe category
  2: RawLoggingDestinationScribe scribe;
}

@rust.Exhaustive
struct RawUpdateLoggingConfig {
  // Destination to log bookmark updates to
  4: optional RawLoggingDestination bookmark_logging_destination;
  // Destination to log new commits to
  7: optional RawLoggingDestination new_commit_logging_destination;
}

@rust.Exhaustive
struct RawCommitGraphConfig {
  // Scuba table to log commit graph operations to
  1: optional string scuba_table;
  /// Blobstore key for the preloaded commit graph
  2: optional string preloaded_commit_graph_blobstore_key;
}

@rust.Exhaustive
struct RawMetadataLoggerConfig {
  // The bookmarks to log repo metadata for
  1: list<string> bookmarks;
  // The interval time in secs for which the repo metadata logger sleeps between
  // successive iterations of its incremental mode execution
  2: i64 sleep_interval_secs;
}

@rust.Type{name = "HashMap"}
typedef map<string, RawAclRegionConfig> map_string_RawAclRegionConfig_3881
@rust.Type{name = "HashMap"}
typedef map<string, RawCommitSyncConfig> map_string_RawCommitSyncConfig_4989
@rust.Type{name = "HashMap"}
typedef map<string, RawRepoConfig> map_string_RawRepoConfig_815
@rust.Type{name = "HashMap"}
typedef map<string, RawRepoDefinition> map_string_RawRepoDefinition_9793
@rust.Type{name = "HashMap"}
typedef map<string, RawStorageConfig> map_string_RawStorageConfig_2830
@rust.Type{name = "HashMap"}
typedef map<string, i32> map_string_i32_6602
@rust.Type{name = "HashMap"}
typedef map<string, i64> map_string_i64_6128
@rust.Type{name = "HashMap"}
typedef map<string, list<i32>> map_string_list_i32_8462
@rust.Type{name = "HashMap"}
typedef map<string, list<i64>> map_string_list_i64_8629
@rust.Type{name = "HashMap"}
typedef map<string, list<string>> map_string_list_string_6265
@rust.Type{name = "HashMap"}
typedef map<string, string> map_string_string_6987
