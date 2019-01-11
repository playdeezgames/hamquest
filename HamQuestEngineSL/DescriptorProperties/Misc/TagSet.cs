using System;
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
using System.Xml.Linq;

namespace HamQuestEngine
{
    public class TagSet
    {
        public static HashSet<string> LoadFromNode(XElement node)
        {
            HashSet<string> result = new HashSet<string>();
            foreach (XElement subElement in node.Elements("tag"))
            {
                if (!result.Contains(subElement.Value))
                {
                    result.Add(subElement.Value);
                }
            }
            return result;
        }
    }
}
