using System;
using System.Xml.Linq;
using PDGBoardGames;

namespace HamQuestEngine.DescriptorProperties
{
    public class PlayerDefendRoller:IRoller
    {
        public static IRoller LoadFromNode(XElement node)
        {
            return new PlayerDefendRoller();
        }

        public int Roll(Descriptor theDescriptor, Game theGame)
        {
            PlayerDescriptor playerDescriptor = theDescriptor as PlayerDescriptor;
            if (playerDescriptor == null) return 0;
            int result = 0;
            foreach (string itemIdentifier in playerDescriptor.EquippedArmors)
            {
                if (itemIdentifier != String.Empty)
                {
                    string defendGeneratorName = (theGame.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).GetProperty<string>(GameConstants.Properties.DefendGenerator));
                    WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(defendGeneratorName);
                    result += generator.Generate(theGame.RandomNumberGenerator);
                }
            }
            return (result);
        }


        public int GetMaximumRoll(Descriptor theDescriptor, Game theGame)
        {
            PlayerDescriptor playerDescriptor = theDescriptor as PlayerDescriptor;
            if (playerDescriptor == null) return 0;
            int result = 0;
            foreach (string itemIdentifier in playerDescriptor.EquippedArmors)
            {
                if (itemIdentifier != String.Empty)
                {
                    string defendGeneratorName = (theGame.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).GetProperty<string>(GameConstants.Properties.DefendGenerator));
                    WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(defendGeneratorName);
                    result += generator.MaximalValue;
                }
            }
            return (result);
        }

        public int GetMinimumRoll(Descriptor theDescriptor, Game theGame)
        {
            PlayerDescriptor playerDescriptor = theDescriptor as PlayerDescriptor;
            if (playerDescriptor == null) return 0;
            int result = 0;
            foreach (string itemIdentifier in playerDescriptor.EquippedArmors)
            {
                if (itemIdentifier != String.Empty)
                {
                    string defendGeneratorName = (theGame.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).GetProperty<string>(GameConstants.Properties.DefendGenerator));
                    WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(defendGeneratorName);
                    result += generator.MinimalValue;
                }
            }
            return (result);
        }
    }
}
