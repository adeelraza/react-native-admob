import {
  NativeModules,
  NativeEventEmitter,
} from 'react-native';

import { createErrorFromErrorData } from './utils';

const RNAdMobInterstitial = NativeModules.RNAdMobInterstitial;

const eventEmitter = new NativeEventEmitter(RNAdMobInterstitial);

const eventMap = {
  adLoaded: 'interstitialAdLoaded',
  adFailedToLoad: 'interstitialAdFailedToLoad',
  adOpened: 'interstitialAdOpened',
  adClosed: 'interstitialAdClosed',
  adLeftApplication: 'interstitialAdLeftApplication',
};

const _subscriptions = new Map();

const addEventListener = (event, handler) => {
  const mappedEvent = eventMap[event];
  if (mappedEvent) {
    let listener;
    if (event === 'adFailedToLoad') {
      listener = eventEmitter.addListener(mappedEvent, error => handler(createErrorFromErrorData(error)));
    } else {
      listener = eventEmitter.addListener(mappedEvent, handler);
    }
    _subscriptions.set(handler, listener);
    return {
      remove: () => removeEventListener(event, handler)
    };
  } else {
    console.warn(`Trying to subscribe to unknown event: "${event}"`);
    return {
      remove: () => {},
    };
  }
};

const removeEventListener = (type, handler) => {
  const listener = _subscriptions.get(handler);
  if (!listener) {
    return;
  }
  listener.remove();
  _subscriptions.delete(handler);
};

const removeAllListeners = () => {
  _subscriptions.forEach((listener, key, map) => {
    listener.remove();
    map.delete(key);
  });
};

const setBirthday = (birthday) => {
  if (birthday && birthday instanceof Date) {
    const month = birthday.getMonth() + 1;
    const day = birthday.getDate();
    const year = birthday.getFullYear();
    RNAdMobInterstitial.setBirthday({ day, month, year });
  }
};

const setChildDirected = (childDirected) => {
  RNAdMobInterstitial.setChildDirected(childDirected);
}

const setContentUrl = (contentUrl) => {
  RNAdMobInterstitial.setContentUrl(contentUrl);
}

const setGender = (gender) => {
  RNAdMobInterstitial.setGender(gender);
}

const setLocation = (location) => {
  RNAdMobInterstitial.setLocation(location);
};

const setTargetingData = (targetingData) => {
  const { birthday, childDirected, contentUrl, gender, location } = targetingData;
  birthday && setBirthday(birthday);
  typeof childDirected !== 'undefined' && setChildDirected(childDirected);
  contentUrl && setContentUrl(contentUrl);
  gender && setGender(gender);
  location && setLocation(location);
};


export default {
  ...RNAdMobInterstitial,
  setTargetingData,
  setGender,
  setBirthday,
  setLocation,
  setChildDirected,
  setContentUrl,
  addEventListener,
  removeEventListener,
  removeAllListeners,
};
