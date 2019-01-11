using System;
using System.Net;
using System.Windows;



using System.Windows.Input;



using System.Collections.Generic;
using System.Xml.Linq;

namespace HamQuestEngine
{
    public interface IMessageStatistics
    {
        Dictionary<string, uint>.KeyCollection GetEntries();
        void AddEntry(string entry);
        uint GetCount(string entry);
    }
    public class PlayerMessageStatistics:IMessageStatistics
    {
        private Dictionary<string, uint> table = new Dictionary<string, uint>();
        public static PlayerMessageStatistics LoadFromNode(XElement node)
        {
            return new PlayerMessageStatistics();
        }

        public Dictionary<string, uint>.KeyCollection GetEntries()
        {
            return table.Keys;
        }

        public void AddEntry(string entry)
        {
            if (table.ContainsKey(entry))
            {
                table[entry]++;
            }
            else
            {
                table.Add(entry, 1);
            }
        }

        public uint GetCount(string entry)
        {
            if (table.ContainsKey(entry))
            {
                return table[entry];
            }
            else
            {
                return 0;
            }
        }
    }
}
