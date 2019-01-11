using System;
using System.Collections.Generic;
using System.Text;
using System.Xml.Linq;

namespace HamQuestEngine
{
    public interface IStatisticHolder
    {
        int Value { get; }
    }
    public class StatisticHolder:IStatisticHolder
    {
        private int value;
        public int Value
        {
            get
            {
                return value;
            }
        }
        public StatisticHolder(int theValue)
        {
            value = theValue;
        }
        public static StatisticHolder LoadFromNode(XElement node)
        {
            int theValue;
            int.TryParse(node.Value, out theValue);
            return new StatisticHolder(theValue);
        }
    }
}
