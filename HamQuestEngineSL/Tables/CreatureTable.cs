using System;
using System.Collections.Generic;
using System.Text;
using PDGBoardGames;
using System.Xml.Linq;
using System.Reflection;
using System.Windows;


namespace HamQuestEngine
{
    public class CreatureTable
    {
        private Dictionary<string, Descriptor> table = new Dictionary<string, Descriptor>();
        private Dictionary<string, List<string>> generatorTables = new Dictionary<string, List<string>>();
        public Dictionary<string, Descriptor>.KeyCollection CreatureIdentifiers
        {
            get
            {
                return (table.Keys);
            }
        }
        public Descriptor GetCreatureDescriptor(string creatureIdentifier)
        {
            return (table[creatureIdentifier]);
        }
        private List<string> GetGeneratorTable(string generatorTable)
        {
            if (generatorTables.ContainsKey(generatorTable))
            {
                return generatorTables[generatorTable];
            }
            else
            {
                List<string> theTable = new List<string>();
                foreach (string identifier in table.Keys)
                {
                    Descriptor descriptor = GetCreatureDescriptor(identifier);
                    if (descriptor.HasProperty(generatorTable))
                    {
                        int count = descriptor.GetProperty<int>(generatorTable);
                        while (count > 0)
                        {
                            theTable.Add(identifier);
                            count--;
                        }
                    }
                }
                generatorTables.Add(generatorTable, theTable);
                return theTable;
            }
        }
        public string GenerateCreature(string generatorTable,IRandomNumberGenerator theRandomNumberGenerator)
        {
            List<string> theTable = GetGeneratorTable(generatorTable);
            return theTable[theRandomNumberGenerator.Next(theTable.Count)];
        }
        private string creaturesFile;
        public void Reset()
        {
            table.Clear();
            XDocument doc = XDocument.Load(creaturesFile);
            foreach (XElement subElement in doc.Element(GameConstants.Properties.Creatures).Elements(GameConstants.Properties.Creature))
            {
                string identifierString;
                PropertyValuePair[] properties = PropertyValuePair.LoadPropertyValuesFromXmlNode(subElement, out identifierString);
                if (subElement.Attribute(GameConstants.Attributes.Type) != null)
                {
                    string typeName = subElement.Attribute(GameConstants.Attributes.Type).Value;
                    Assembly assembly = Assembly.GetExecutingAssembly();
                    Type[] types = assembly.GetExportedTypes();
                    foreach (Type type in types)
                    {
                        if (type.Name == typeName)
                        {
                            MethodInfo methodInfo = type.GetMethod(GameConstants.Methods.LoadCustomDescriptor);
                            table.Add(identifierString,(Descriptor)methodInfo.Invoke(null, new object[] { properties }));
                            break;
                        }
                    }
                }
                else
                {
                    table.Add(identifierString, new Descriptor(properties));
                }
            }
        }
        public CreatureTable():this(GameConstants.FileNames.DefaultCreaturesFile)
        {
        }
        public CreatureTable(string theCreaturesFile)
        {
            creaturesFile = theCreaturesFile;
            Reset();
        }
    }
}
