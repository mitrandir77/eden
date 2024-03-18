/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/store/BackingStoreLogger.h"

#include <folly/Conv.h>

#include "eden/common/telemetry/StructuredLogger.h"
#include "eden/common/utils/ProcessInfoCache.h"
#include "eden/common/utils/UnboundedQueueExecutor.h"
#include "eden/fs/store/ObjectFetchContext.h"
#include "eden/fs/telemetry/LogEvent.h"

namespace facebook::eden {

BackingStoreLogger::BackingStoreLogger(
    std::shared_ptr<StructuredLogger> logger,
    std::shared_ptr<ProcessInfoCache> processInfoCache)
    : logger_{std::move(logger)},
      processInfoCache_{std::move(processInfoCache)},
      loggingAvailable_{true} {}

void BackingStoreLogger::logImport(
    const ObjectFetchContext& context,
    RelativePathPiece importPath,
    ObjectFetchContext::ObjectType fetchedType) {
  if (!loggingAvailable_) {
    return;
  }
  auto pid = context.getClientPid();
  auto cause = context.getCause();
  auto importPathString = importPath.asString();

  std::optional<std::string> cmdline;
  if (pid) {
    cmdline = processInfoCache_->getProcessName(pid.value().get());
  }

  std::string cause_string = "<invalid>";
  switch (cause) {
    case ObjectFetchContext::Cause::Fs:
      cause_string = "FS";
      break;
    case ObjectFetchContext::Cause::Thrift:
      cause_string = "Thrift";
      break;
    case ObjectFetchContext::Cause::Prefetch:
      cause_string = "Prefetch";
      break;
    case ObjectFetchContext::Unknown:
      cause_string = "Unknown";
  }
  if (auto causeDetail = context.getCauseDetail()) {
    cause_string =
        folly::to<std::string>(cause_string, " - ", causeDetail.value());
  }

  std::string typeString = "<invalid>";
  switch (fetchedType) {
    case ObjectFetchContext::ObjectType::Blob:
      typeString = "Blob";
      break;
    case ObjectFetchContext::ObjectType::BlobMetadata:
      typeString = "Blob Metadata";
      break;
    case ObjectFetchContext::ObjectType::Tree:
      typeString = "Tree";
      break;
    case ObjectFetchContext::ObjectType::kObjectTypeEnumMax:
      // invalid string prolly good here
      break;
  }

  if (cmdline) {
    std::replace(cmdline->begin(), cmdline->end(), '\0', ' ');
  }

  logger_->logEvent(ServerDataFetch{
      std::move(cause_string),
      pid,
      std::move(cmdline),
      std::move(importPathString),
      std::move(typeString)});
}

} // namespace facebook::eden
