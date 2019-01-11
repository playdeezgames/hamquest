using System;
using System.Collections.Generic;
using System.Text;
using System.Xml.Linq;
using System.Reflection;

namespace HamQuestEngine
{
    public class TerrainTable
    {
        private Dictionary<string, Descriptor> table = new Dictionary<string, Descriptor>();
        public Descriptor GetTerrainDescriptor(string theMapTerrainIdentifier)
        {
            Descriptor result = null;
            if (table.ContainsKey(theMapTerrainIdentifier))
            {
                result = table[theMapTerrainIdentifier];
            }
            return (result);
        }
        public TerrainTable()
        {
            table.Clear();
            XDocument doc = XDocument.Load("config/terrains.xml");
            foreach(XElement subElement in doc.Element("terrains").Elements("terrain"))
            {
                string identifierString;
                PropertyValuePair[] properties = PropertyValuePair.LoadPropertyValuesFromXmlNode(subElement, out identifierString);
                table.Add(identifierString, new Descriptor(properties));
            }
        }
    }
}
