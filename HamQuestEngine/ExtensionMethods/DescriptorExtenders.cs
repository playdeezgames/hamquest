using System;
using System.Net;
using System.Windows;



using System.Windows.Input;



using System.Collections.Generic;

namespace HamQuestEngine
{
    public static class DescriptorExtenders
    {
        public static bool HasTag(this Descriptor theDescriptor, string theTag)
        {
            if (theDescriptor == null) return false;
            HashSet<string> theHashSet = theDescriptor.GetProperty<HashSet<string>>(GameConstants.Properties.Tags);
            if (theHashSet == null) return false;
            return theHashSet.Contains(theTag);
        }
        public static int GetHealth(this Descriptor theDescriptor)
        {
            if(theDescriptor==null) return 0;
            IStatisticHolder holder = theDescriptor.GetProperty<IStatisticHolder>(GameConstants.Properties.Health);
            if (holder == null) return 0;
            return holder.Value;
        }
    }
}
