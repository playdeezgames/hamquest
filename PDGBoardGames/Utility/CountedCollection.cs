using System;
using System.Collections.Generic;

namespace PDGBoardGames
{
    public class CountedCollection<TCounted> where TCounted:IComparable
    {
        private Dictionary<TCounted, uint> _counts = new Dictionary<TCounted, uint>();
        public Dictionary<TCounted, uint>.KeyCollection Values
        {
            get
            {
                return (_counts.Keys);
            }
        }
        public void Add(TCounted identifier, uint count)
        {
            if (_counts.ContainsKey(identifier))
            {
                _counts[identifier] += count;
            }
            else
            {
                _counts.Add(identifier, count);
            }
        }
        public void Add(TCounted identifier)
        {
            Add(identifier, 1);
        }
        public bool Has(TCounted identifier)
        {
            return _counts.ContainsKey(identifier) && _counts[identifier] > 0;
        }
        public uint this[TCounted identifier]
        {
            get
            {
                if (Has(identifier))
                {
                    return (_counts[identifier]);
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
                    _counts[identifier] = value;
                }
                else
                {
                    _counts.Add(identifier, value);
                }
            }
        }
        public uint Remove(TCounted identifier, uint count)
        {
            if (_counts.ContainsKey(identifier))
            {
                if (count >= _counts[identifier])
                {
                    count = _counts[identifier];
                    _counts.Remove(identifier);
                    return (count);
                }
                else
                {
                    _counts[identifier] -= count;
                    return (count);
                }
            }
            else
            {
                return (0);
            }
        }
        public bool Remove(TCounted identifier)
        {
            return Remove(identifier, 1) > 0;
        }
    }
}
