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
    public class ThemeTable
    {
        private Dictionary<string, Descriptor> table = new Dictionary<string, Descriptor>();
        public Descriptor GetPropertyDescriptor(string thePropertyIdentifier)
        {
            Descriptor result = null;
            if (table.ContainsKey(thePropertyIdentifier))
            {
                result = table[thePropertyIdentifier];
            }
            return (result);
        }
        public Dictionary<string, Descriptor>.KeyCollection PropertyIdentifiers
        {
            get
            {
                return (table.Keys);
            }
        }
        public ThemeTable():this(GameConstants.FileNames.DefaultThemesFile)
        {
        }
        public ThemeTable(string theFileName)
        {
            table.Clear();
            XDocument doc = XDocument.Load(theFileName);
            foreach (XElement subElement in doc.Element(GameConstants.Properties.Themes).Elements(GameConstants.Properties.Themes))
            {
                string identifier;
                PropertyValuePair[] properties = PropertyValuePair.LoadPropertyValuesFromXmlNode(subElement, out identifier);
                table.Add(identifier, new Descriptor(properties));

            }
        }

    }
}
