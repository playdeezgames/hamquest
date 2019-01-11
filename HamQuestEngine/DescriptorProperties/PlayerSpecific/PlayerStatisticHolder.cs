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
