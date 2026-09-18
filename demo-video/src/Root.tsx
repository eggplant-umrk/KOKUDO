import React from 'react';
import { Composition } from 'remotion';
import { KokudoDemoVideo } from './Video';
import { FPS, TOTAL_FRAMES_WITH_OVERLAP } from './durations';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="KokudoDemo"
      component={KokudoDemoVideo}
      durationInFrames={TOTAL_FRAMES_WITH_OVERLAP}
      fps={FPS}
      width={1920}
      height={1080}
    />
  );
};
