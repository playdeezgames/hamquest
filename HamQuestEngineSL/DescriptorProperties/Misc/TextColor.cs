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
using System.Xml.Linq;

namespace HamQuestEngine
{
    public class TextColor
    {
        public static Color LoadFromNode(XElement node)
        {
            byte a = byte.Parse(node.Element(GameConstants.Properties.Alpha).Value);
            byte r = byte.Parse(node.Element(GameConstants.Properties.Red).Value);
            byte g = byte.Parse(node.Element(GameConstants.Properties.Green).Value);
            byte b = byte.Parse(node.Element(GameConstants.Properties.Blue).Value);
            return Color.FromArgb(a,r,g,b);
        }
    }
}
