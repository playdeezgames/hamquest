using System;
using System.Collections.Generic;
using System.Text;
using PDGBoardGames;

namespace PDGBoardGames
{
    public class WeightedGenerator<GeneratedType> where GeneratedType:IComparable
    {
        private Dictionary<GeneratedType, uint> generationTable = new Dictionary<GeneratedType, uint>();
        private uint weightTotal=0;
        public void Clear()
        {
            generationTable.Clear();
        }
        public GeneratedType MinimalValue
        {
            get
            {
                GeneratedType result = default(GeneratedType);
                foreach (GeneratedType value in generationTable.Keys)
                {
                    if (result.CompareTo(value) > 0)
                    {
                        result = value;
                    }
                }
                return result;
            }
        }
        public GeneratedType MaximalValue
        {
            get
            {
                GeneratedType result = default(GeneratedType);
                foreach (GeneratedType value in generationTable.Keys)
                {
                    if (result.CompareTo(value) < 0)
                    {
                        result = value;
                    }
                }
                return result;
            }
        }
        private void SetWeight(GeneratedType theValue, uint theWeight)
        {
            if (generationTable.ContainsKey(theValue))
            {
                weightTotal -= generationTable[theValue];
                generationTable[theValue] = theWeight;
            }
            else
            {
                generationTable.Add(theValue, theWeight);
            }
            weightTotal += generationTable[theValue];
        }
        private uint GetWeight(GeneratedType theValue)
        {
            if (generationTable.ContainsKey(theValue))
            {
                return generationTable[theValue];
            }
            else
            {
                return 0;
            }
        }
        public GeneratedType Generate(IRandomNumberGenerator theRandomNumberGenerator)
        {
            if (weightTotal > 0)
            {
                uint randomValue = (uint)theRandomNumberGenerator.Next((int)weightTotal);
                foreach (GeneratedType generatedValue in generationTable.Keys)
                {
                    if (randomValue < generationTable[generatedValue])
                    {
                        return (generatedValue);
                    }
                    else
                    {
                        randomValue -= generationTable[generatedValue];
                    }
                }
            }
            return default(GeneratedType);
        }
        public uint this[GeneratedType theValue]
        {
            get
            {
                return GetWeight(theValue);
            }
            set
            {
                SetWeight(theValue, value);
            }
        }
        public WeightedGenerator()
        {
        }
    }
}
