/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import type {
  ApplyPreviewsFuncType,
  DagPreviewContext,
  DagWithPreview,
  PreviewContext,
} from '../previews';
import type {ExactRevset, Hash, SucceedableRevset} from '../types';

import {latestSuccessor} from '../SuccessionTracker';
import {t} from '../i18n';
import {CommitPreview} from '../previews';
import {Operation} from './Operation';

export class RebaseOperation extends Operation {
  constructor(
    private source: ExactRevset | SucceedableRevset,
    private destination: ExactRevset | SucceedableRevset,
  ) {
    super('RebaseOperation');
  }

  static opName = 'Rebase';

  getArgs() {
    return ['rebase', '-s', this.source, '-d', this.destination];
  }

  getInitialInlineProgress(): Array<[string, string]> {
    // TODO: successions
    return [[this.source.revset, t('rebasing...')]];
  }

  makePreviewApplier(context: PreviewContext): ApplyPreviewsFuncType | undefined {
    const {treeMap} = context;
    const originalSourceNode = treeMap.get(latestSuccessor(context, this.source));
    if (originalSourceNode == null) {
      return undefined;
    }
    const newSourceNode = {
      ...originalSourceNode,
      info: {...originalSourceNode.info},
    };
    let parentHash: Hash;

    const func: ApplyPreviewsFuncType = (tree, previewType) => {
      if (tree.info.hash === latestSuccessor(context, this.source)) {
        if (tree.info.parents[0] === parentHash) {
          // this is the newly added node
          return {
            info: tree.info,
            children: tree.children,
            previewType: CommitPreview.REBASE_ROOT, // root will show confirmation button
            childPreviewType: CommitPreview.REBASE_DESCENDANT, // children should also show as previews, but don't all need the confirm button
          };
        } else {
          // this is the original source node
          return {
            info: tree.info,
            children: tree.children,
            previewType: CommitPreview.REBASE_OLD,
            childPreviewType: CommitPreview.REBASE_OLD,
          };
        }
      } else if (
        tree.info.hash === latestSuccessor(context, this.destination) ||
        tree.info.remoteBookmarks.includes(this.destination.revset)
      ) {
        parentHash = tree.info.hash;
        newSourceNode.info.parents = [parentHash];
        // we always want the rebase preview to be the lowest child aka last in list
        return {
          info: tree.info,
          children: [...tree.children, newSourceNode],
        };
      } else {
        return {
          info: tree.info,
          children: tree.children,
          previewType,
          // inherit previews so entire subtree is previewed
          childPreviewType: previewType,
        };
      }
    };
    return func;
  }

  optimisticDag(dag: DagWithPreview, context: DagPreviewContext): DagWithPreview {
    const src = dag.resolve(latestSuccessor(context, this.source));
    const dest = dag.resolve(latestSuccessor(context, this.destination));
    return dag.rebase(dag.descendants(src?.hash), dest?.hash);
  }
}
