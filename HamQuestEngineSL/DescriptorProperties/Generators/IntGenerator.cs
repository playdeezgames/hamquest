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
    public class IntGenerator
    {
        public static WeightedGenerator<int> LoadFromNode(XElement node)
        {
            WeightedGenerator<int> result = new WeightedGenerator<int>();
            foreach (XElement subElement in node.Elements("entry"))
            {
                string valueString = subElement.Element("value").Value;
                string weightString = subElement.Element("weight").Value;
                uint weight;
                int value;
                if (uint.TryParse(weightString, out weight) && int.TryParse(valueString,out value))
                {
                    result[value]= weight;
                }
            }
            return result;
        }
    }
}
