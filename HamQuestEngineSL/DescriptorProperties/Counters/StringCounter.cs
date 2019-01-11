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
using PDGBoardGames;
using System.Xml.Linq;

namespace HamQuestEngine
{
    public class StringCounter
    {
        public static CountedCollection<string> LoadFromNode(XElement node)
        {
            CountedCollection<string> result = new CountedCollection<string>();
            foreach (XElement subElement in node.Elements("entry"))
            {
                string identifier = subElement.Element("value").Value;
                string weightString = subElement.Element("count").Value;
                uint weight;
                if (uint.TryParse(weightString, out weight))
                {
                    result.Add(identifier, weight);
                }
            }
            return result;
        }

    }
}
