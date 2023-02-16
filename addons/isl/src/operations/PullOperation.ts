/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {Operation} from './Operation';

export class PullOperation extends Operation {
  static opName = 'Pull';

  constructor() {
    super('PullOperation');
  }

  getArgs() {
    return ['pull'];
  }
}
