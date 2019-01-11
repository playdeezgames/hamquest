using System.Xml.Linq;
using PDGBoardGames;

namespace HamQuestEngine
{
    public class CreatureDefendRoller:IRoller
    {
        public static IRoller LoadFromNode(XElement node)
        {
            return new CreatureDefendRoller();
        }


        public int Roll(Descriptor theDescriptor, Game theGame)
        {
            string generatorName = theDescriptor.GetProperty<string>(GameConstants.Properties.DefendGenerator);
            WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(generatorName);
            return generator.Generate(theGame.RandomNumberGenerator);
        }


        public int GetMaximumRoll(Descriptor theDescriptor, Game theGame)
        {
            string generatorName = theDescriptor.GetProperty<string>(GameConstants.Properties.DefendGenerator);
            WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(generatorName);
            return generator.MaximalValue;
        }

        public int GetMinimumRoll(Descriptor theDescriptor, Game theGame)
        {
            string generatorName = theDescriptor.GetProperty<string>(GameConstants.Properties.DefendGenerator);
            WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(generatorName);
            return generator.MinimalValue;
        }
    }
}
