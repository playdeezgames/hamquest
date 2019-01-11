﻿using System;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace HamQuestSLClient
{
    public class SoundEffectsManager : MediaElementManager<string>
    {
        private void MutedChanged(bool isMuted)
        {
            foreach (string key in Keys)
            {
                this[key].IsMuted = isMuted;
            }
        }
        private void VolumeChanged(double newVolume)
        {
            foreach (string key in Keys)
            {
                this[key].Volume = newVolume;
            }
        }
        private void MediaElementAdded(string theKey, MediaElement theMediaElement)
        {
            theMediaElement.Volume = Volume;
            theMediaElement.IsMuted = Muted;
        }
        private void MediaElementChanged(string theKey, MediaElement theOldMediaElement, MediaElement theNewMediaElement)
        {
            theOldMediaElement.Stop();
            theNewMediaElement.IsMuted = Muted;
            theNewMediaElement.Volume = Volume;
        }
        public SoundEffectsManager()
        {
            OnMutedChanged += MutedChanged;
            OnVolumeChanged += VolumeChanged;
            OnMediaElementAdded += MediaElementAdded;
            OnMediaElementChanged += MediaElementChanged;
        }
    }
}

