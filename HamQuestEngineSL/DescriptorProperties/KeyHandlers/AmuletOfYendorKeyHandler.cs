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
    public class AmuletOfYendorKeyHandler:IPlayerKeyHandler
    {
        public static IPlayerKeyHandler LoadFromNode(XElement node)
        {
            return new AmuletOfYendorKeyHandler(node.Element(GameConstants.Properties.AmuletItemName).Value);
        }

        private string amuletItemName;
        public AmuletOfYendorKeyHandler(string theAmuletItemName)
        {
            amuletItemName = theAmuletItemName;
        }

        public bool HandleKey(Key key, Descriptor descriptor)
        {
            if (key == Key.Y)
            {
                PlayerDescriptor playerDescriptor = descriptor as PlayerDescriptor;
                if (playerDescriptor != null)
                {
                    if (playerDescriptor.Items[amuletItemName] > 0)
                    {
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.Maze.Game.TableSet.ItemTable.GetItemDescriptor(amuletItemName).GetProperty<string>(GameConstants.Properties.UseMessage));
                        playerDescriptor.MapCreature.Map[playerDescriptor.MapCreature.Column][playerDescriptor.MapCreature.Row].ItemIdentifier = amuletItemName;
                        playerDescriptor.Items.Remove(amuletItemName);
                        playerDescriptor.MapCreature.Remove();
                        playerDescriptor.Teleport();
                        playerDescriptor.MapCreature.Place();
                        return true;
                    }
                }
            }
            return false;
        }
    }
}
