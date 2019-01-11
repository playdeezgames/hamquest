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
using System.Collections.Generic;

namespace HamQuestSLClient
{
    public delegate void MutedChangedDelegate(bool isMuted);
    public delegate void VolumeChangedDelegate(double theVolume);
    public delegate void MediaElementAddedDelegate<EnumType>(EnumType theKey, MediaElement theMediaElement);
    public delegate void MediaElementChangedDelegate<EnumType>(EnumType theKey, MediaElement theOldMediaElement, MediaElement theNewMediaElement);
    public abstract class MediaElementManager<EnumType>
    {
        private const double DefaultVolume = 0.5;
        private const bool DefaultMuted = false;

        private Dictionary<EnumType, MediaElement> mediaElementTable = new Dictionary<EnumType, MediaElement>();

        public Dictionary<EnumType, MediaElement>.KeyCollection Keys
        {
            get
            {
                return mediaElementTable.Keys;
            }
        }

        private event MutedChangedDelegate onMutedChanged;
        private event VolumeChangedDelegate onVolumeChanged;
        private event MediaElementAddedDelegate<EnumType> onMediaElementAdded;
        private event MediaElementChangedDelegate<EnumType> onMediaElementChanged;

        private bool muted;
        private double volume;

        public event MutedChangedDelegate OnMutedChanged
        {
            add
            {
                onMutedChanged += value;
            }
            remove
            {
                onMutedChanged -= value;
            }
        }
        public event VolumeChangedDelegate OnVolumeChanged
        {
            add
            {
                onVolumeChanged += value;
            }
            remove
            {
                onVolumeChanged -= value;
            }
        }
        public event MediaElementChangedDelegate<EnumType> OnMediaElementChanged
        {
            add
            {
                onMediaElementChanged += value;
            }
            remove
            {
                onMediaElementChanged -= value;
            }
        }
        public event MediaElementAddedDelegate<EnumType> OnMediaElementAdded
        {
            add
            {
                onMediaElementAdded += value;
            }
            remove
            {
                onMediaElementAdded += value;
            }
        }
        public bool Muted
        {
            get
            {
                return muted;
            }
            set
            {
                muted = value;
                if (onMutedChanged != null)
                {
                    onMutedChanged(muted);
                }
            }
        }
        public double Volume
        {
            get
            {
                return volume;
            }
            set
            {
                volume = value;
                if (onVolumeChanged != null)
                {
                    onVolumeChanged(volume);
                }
            }
        }

        public MediaElement this[EnumType theKey]
        {
            get
            {
                return mediaElementTable[theKey];
            }
            set
            {
                SetMediaElement(theKey, value);
            }
        }

        private void SetMediaElement(EnumType theKey, MediaElement theMediaElement)
        {
            if (mediaElementTable.ContainsKey(theKey))
            {
                MediaElement oldMediaElement = mediaElementTable[theKey];
                mediaElementTable[theKey] = theMediaElement;
                if (onMediaElementChanged != null)
                {
                    onMediaElementChanged(theKey, oldMediaElement, theMediaElement);
                }
            }
            else
            {
                mediaElementTable.Add(theKey, theMediaElement);
                if (onMediaElementAdded != null)
                {
                    onMediaElementAdded(theKey, theMediaElement);
                }
            }
        }

        public void Play(EnumType theKey)
        {
            if (mediaElementTable.ContainsKey(theKey) && !Muted)
            {
                mediaElementTable[theKey].Stop();
                mediaElementTable[theKey].Play();
            }
        }

        public MediaElementManager()
            : this(DefaultVolume, DefaultMuted)
        {

        }
        public MediaElementManager(double theVolume, bool isMuted)
        {
            Volume = theVolume;
            Muted = isMuted;
        }
    }
}
