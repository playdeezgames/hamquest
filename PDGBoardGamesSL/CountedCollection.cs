using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace PDGBoardGames
{
    public class CountedCollection<CountedType> where CountedType:IComparable
    {
        private Dictionary<CountedType, uint> counts = new Dictionary<CountedType, uint>();
        public Dictionary<CountedType, uint>.KeyCollection Identifiers
        {
            get
            {
                return (counts.Keys);
            }
        }
        public CountedType MinimalValue
        {
            get
            {
                CountedType result = default(CountedType);
                foreach (CountedType value in counts.Keys)
                {
                    if (result.CompareTo(value) > 0)
                    {
                        result = value;
                    }
                }
                return result;
            }
        }
        public CountedType MaximalValue
        {
            get
            {
                CountedType result = default(CountedType);
                foreach (CountedType value in counts.Keys)
                {
                    if (result.CompareTo(value) < 0)
                    {
                        result = value;
                    }
                }
                return result;
            }
        }
        public void Add(CountedType identifier, uint count)
        {
            if (counts.ContainsKey(identifier))
            {
                counts[identifier] += count;
            }
            else
            {
                counts.Add(identifier, count);
            }
        }
        public void Add(CountedType identifier)
        {
            Add(identifier, 1);
        }
        public bool Has(CountedType identifier)
        {
            return counts.ContainsKey(identifier) && counts[identifier] > 0;
        }
        public uint this[CountedType identifier]
        {
            get
            {
                if (Has(identifier))
                {
                    return (counts[identifier]);
                }
                else
                {
                    return (0);
                }
            }
            set
            {
                if (Has(identifier))
                {
                    counts[identifier] = value;
                }
                else
                {
                    counts.Add(identifier, value);
                }
            }
        }
        public uint Remove(CountedType identifier, uint count)
        {
            if (counts.ContainsKey(identifier))
            {
                if (count >= counts[identifier])
                {
                    count = counts[identifier];
                    counts.Remove(identifier);
                    return (count);
                }
                else
                {
                    counts[identifier] -= count;
                    return (count);
                }
            }
            else
            {
                return (0);
            }
        }
        public bool Remove(CountedType identifier)
        {
            return Remove(identifier, 1) > 0;
        }
    }
}
