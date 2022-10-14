/*
 * Tencent is pleased to support the open source community by making
 * Hippy available.
 *
 * Copyright (C) 2017-2019 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* eslint-disable no-undef */
/* eslint-disable no-underscore-dangle */

const { JSTimersExecution } = require('../../modules/ios/jsTimersExecution.js');

global.__hpBatchedBridge = {};

__hpBatchedBridge.flushedQueue = () => {
  JSTimersExecution.callImmediates();
  const queue = __GLOBAL__._queue;
  __GLOBAL__._queue = [[], [], [], __GLOBAL__._callID];
  return queue[0].length ? queue : null;
};

__hpBatchedBridge.invokeCallbackAndReturnFlushedQueue = (cbID, args) => {
  __hpBatchedBridge.__invokeCallback(cbID, args);
  JSTimersExecution.callImmediates();
  return __hpBatchedBridge.flushedQueue();
};

__hpBatchedBridge.__invokeCallback = (cbID, args) => {
  const callback = __GLOBAL__._callbacks[cbID];
  if (!callback) return;
  if (!__GLOBAL__._notDeleteCallbackIds[cbID & ~1]
     && !__GLOBAL__._notDeleteCallbackIds[cbID | 1]) {
    delete __GLOBAL__._callbacks[cbID & ~1];
    delete __GLOBAL__._callbacks[cbID | 1];
  }
  if (args && args.length > 1 && (args[0] === null || args[0] === undefined)) {
    args.splice(0, 1);
  }
  callback(...args);
};

__hpBatchedBridge.callFunctionReturnFlushedQueue = (module, method, args) => {
  if (module === 'EventDispatcher' || module === 'Dimensions') {
    const targetModule = __GLOBAL__.jsModuleList[module];
    if (!targetModule || !targetModule[method] || typeof targetModule[method] !== 'function') {
    } else {
      targetModule[method].call(targetModule, args[1].params);
    }
  } else if (module === 'JSTimersExecution') {
    if (method === 'callTimers') {
      args[0].forEach((timerId) => {
        const timerCallFunc = JSTimersExecution.callbacks[
          JSTimersExecution.timerIDs.indexOf(timerId)
        ];
        if (typeof timerCallFunc === 'function') {
          try {
            timerCallFunc();
          } catch (e) {
            console.reportUncaughtException(e); // eslint-disable-line
          }
        }
      });
    }
  }
  JSTimersExecution.callImmediates();
  return __hpBatchedBridge.flushedQueue();
};