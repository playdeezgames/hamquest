using System;
using System.Net;
using System.Windows;



using System.Windows.Input;



using System.Xml.Linq;
using PDGBoardGames;

namespace HamQuestEngine
{
    public class SimpleRoller:IRoller
    {
        public static IRoller LoadFromNode(XElement node)
        {
            return new SimpleRoller(node.Value);
        }

        private SimpleRoller() { }

        private string generatorName = string.Empty;

        public SimpleRoller(string theGeneratorName)
        {
            generatorName = theGeneratorName;
        }

        public int Roll(Descriptor theDescriptor, Game theGame)
        {
            WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(generatorName);
            return generator.Generate(theGame.RandomNumberGenerator);
        }


        public int GetMaximumRoll(Descriptor theDescriptor, Game theGame)
        {
            WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(generatorName);
            return generator.MaximalValue;
        }

        public int GetMinimumRoll(Descriptor theDescriptor, Game theGame)
        {
            WeightedGenerator<int> generator = theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.Generators).GetProperty<WeightedGenerator<int>>(generatorName);
            return generator.MinimalValue;
        }
    }
}
