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
using System.Xml.Linq;

namespace HamQuestEngine
{
    public delegate int PlayerStatisticHolderDelegate();
    public class PlayerStatisticHolder : IStatisticHolder
    {
        public PlayerStatisticHolderDelegate GetValue;
        public PlayerStatisticHolder()
        {
        }
        public int Value
        {
            get
            {
                return GetValue();
            }
        }
        public static PlayerStatisticHolder LoadFromNode(XElement node)
        {
            return new PlayerStatisticHolder();
        }
    }
}
