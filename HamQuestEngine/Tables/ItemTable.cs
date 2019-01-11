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
    public class ItemTable
    {
        public WeightedGenerator<int> LockTypeGenerator = new WeightedGenerator<int>();
        private Dictionary<string, Descriptor> table = new Dictionary<string, Descriptor>();
        public Descriptor GetItemDescriptor(string theItemIdentifier)
        {
            Descriptor result = null;
            if (table.ContainsKey(theItemIdentifier))
            {
                result = table[theItemIdentifier];
            }
            return (result);
        }
        public Dictionary<string, Descriptor>.KeyCollection ItemIdentifiers
        {
            get
            {
                return (table.Keys);
            }
        }
        public ItemTable()
            : this(GameConstants.FileNames.DefaultItemsFile)
        {
        }
        public ItemTable(string theItemsFileName)
        {
            table.Clear();
            table.Add(String.Empty, null);
            XDocument doc = XDocument.Load(theItemsFileName);
            foreach(XElement subElement in doc.Element(GameConstants.Properties.Items).Elements(GameConstants.Properties.Item))
            {
                string identifier;
                PropertyValuePair[] properties = PropertyValuePair.LoadPropertyValuesFromXmlNode(subElement, out identifier);
                table.Add(identifier, new Descriptor(properties));
            }

            keyTable.Clear();
            doorTable.Clear();
            foreach (string itemIdentifier in table.Keys)
            {
                Descriptor itemDescriptor = table[itemIdentifier];
                if (itemDescriptor == null) continue;
                if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Key)
                {
                    keyTable.Add(itemDescriptor.GetProperty<int>(GameConstants.Properties.LockType), itemIdentifier);
                    LockTypeGenerator[itemDescriptor.GetProperty<int>(GameConstants.Properties.LockType)]=(uint)itemDescriptor.GetProperty<int>(GameConstants.Properties.LockTypeWeight);
                }
                if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Door)
                {
                    if (!doorTable.ContainsKey(itemDescriptor.GetProperty<int>(GameConstants.Properties.LockType)))
                    {
                        doorTable.Add(itemDescriptor.GetProperty<int>(GameConstants.Properties.LockType), new Dictionary<int, string>());
                    }
                    doorTable[itemDescriptor.GetProperty<int>(GameConstants.Properties.LockType)].Add(itemDescriptor.GetProperty<int>(GameConstants.Properties.Direction), itemIdentifier);
                }
            }

        }
        private Dictionary<int, Dictionary<int, string>> doorTable = new Dictionary<int, Dictionary<int, string>>();
        private Dictionary<int, string> keyTable = new Dictionary<int, string>();
        public string GetDoorItemIdentifier(int lockType, int direction)
        {
            return (doorTable[lockType][direction]);
        }
        public string GetKeyItemIdentifier(int lockType)
        {
            return (keyTable[lockType]);
        }
        public int QuestItemCount
        {
            get
            {
                int result = 0;
                foreach (string identifier in table.Keys)
                {
                    Descriptor descriptor = GetItemDescriptor(identifier);
                    if (descriptor != null && descriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Quest)
                    {
                        result += descriptor.GetProperty<int>(GameConstants.Properties.ItemCount);
                    }
                }
                return result;
            }
        }
    }
}
