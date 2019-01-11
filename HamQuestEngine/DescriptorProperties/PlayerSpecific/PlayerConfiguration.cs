using System.Xml.Linq;

namespace HamQuestEngine
{
    public delegate void PlayerConfigurationChangeDelegate();
    public class PlayerConfiguration
    {
        public static HamQuestEngine.PlayerConfiguration LoadFromNode(XElement node)
        {
            return new HamQuestEngine.PlayerConfiguration(node.Value);
        }
        private string current = string.Empty;
        private PlayerConfigurationChangeDelegate onChange=null;
        public string Current
        {
            get
            {
                return current;
            }
            set
            {
                current = value;
                if (onChange != null)
                {
                    onChange();
                }
            }
        }
        public PlayerConfigurationChangeDelegate OnChange
        {
            get
            {
                return onChange;
            }
            set
            {
                onChange = value;
            }
        }
        public PlayerConfiguration(string theCurrent)
        {
            current = theCurrent;
        }
    }
}
