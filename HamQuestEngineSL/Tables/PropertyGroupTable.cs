using System;
using System.Collections.Generic;
using System.Text;
using System.Diagnostics;
using System.Xml.Linq;
using System.IO;
using System.Reflection;
using PDGBoardGames;

namespace HamQuestEngine
{
    public class PropertyGroupTable
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
        public PropertyGroupTable():this(GameConstants.FileNames.DefaultPropertyGroupsFile)
        {
        }
        public PropertyGroupTable(string theFileName)
        {
            table.Clear();
            XDocument doc = XDocument.Load(theFileName);
            foreach (XElement subElement in doc.Element(GameConstants.Properties.PropertyGroups).Elements(GameConstants.Properties.PropertyGroup))
            {
                string identifier;
                PropertyValuePair[] properties = PropertyValuePair.LoadPropertyValuesFromXmlNode(subElement, out identifier);
                table.Add(identifier, new Descriptor(properties));

            }
        }
    }
}
