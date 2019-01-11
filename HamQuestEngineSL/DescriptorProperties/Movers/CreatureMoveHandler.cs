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
using PDGBoardGames;

namespace HamQuestEngine
{
    public class CreatureMoveHandler:IMover
    {
        public CreatureMoveHandler()
        {
        }
        public void DoMove(Creature theCreature, ref int nextColumn, ref int nextRow, Game theGame)
        {
            Descriptor creatureDescriptor = theGame.TableSet.CreatureTable.GetCreatureDescriptor(theCreature.CreatureIdentifier);
            if (nextColumn < 0 || nextRow < 0 || nextColumn >= theCreature.Map.Columns || nextRow >= theCreature.Map.Rows)
            {
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (theGame.TableSet.TerrainTable.GetTerrainDescriptor(theCreature.Map[nextColumn][nextRow].TerrainIdentifier).GetProperty<IBumpHandler>(GameConstants.Properties.BumpHandler).Bump(theGame.TableSet.TerrainTable.GetTerrainDescriptor(theCreature.Map[nextColumn][nextRow].TerrainIdentifier), theCreature) != BumpResult.Allow)
            {
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (theCreature.Map[nextColumn][nextRow].Creature != null)
            {
                Creature creature = theCreature.Map[nextColumn][nextRow].Creature;
                if (creature == Map.PlayerCreature)
                {
                    theCreature.Steps = 0.0f;//avoid multiple hits per move!
                    PlayerDescriptor descriptor = theGame.TableSet.CreatureTable.GetCreatureDescriptor(creature.CreatureIdentifier) as PlayerDescriptor;
                    int numberOfAttacks = creatureDescriptor.GetProperty<int>(GameConstants.Properties.NumberOfAttacks);
                    while (numberOfAttacks > 0 && !creature.Dead)
                    {
                        int attackRoll = theCreature.RollAttack();
                        int defendRoll = creature.RollDefend();
                        int damage = attackRoll - defendRoll;
                        if (damage > 0)
                        {
                            if (creatureDescriptor.GetProperty<string>(GameConstants.Properties.SpecialAttack) == GameConstants.CreatureSpecialAttacks.Thief && descriptor.QuestItems > 0 && theGame.RandomNumberGenerator.Next(10) == 0)
                            {
                                descriptor.QuestItems--;
                                descriptor.Maze.RespawnItem(descriptor.GetProperty<string>(GameConstants.Properties.QuestItemName));
                                descriptor.MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.GainExperiencePointMessage));
                            }
                            else if (creatureDescriptor.GetProperty<string>(GameConstants.Properties.SpecialAttack) == GameConstants.CreatureSpecialAttacks.Thief && descriptor.Money > 0)
                            {
                                uint gold = (uint)theGame.RandomNumberGenerator.Next(100 * damage);
                                if (gold > descriptor.Money)
                                {
                                    descriptor.Money = 0;
                                }
                                else
                                {
                                    descriptor.Money -= gold;
                                }
                                descriptor.Maze.RespawnItem(theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.PlayerConstants).GetProperty<string>(GameConstants.Properties.CurrencyItemIdentifier));
                                descriptor.MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.ThiefTookGoldMessage));
                            }
                            else if (creatureDescriptor.GetProperty<string>(GameConstants.Properties.SpecialAttack) == GameConstants.CreatureSpecialAttacks.Ghoul && descriptor.ExperiencePoints > 0)
                            {
                                descriptor.ExperiencePoints -= damage;
                                if (descriptor.ExperiencePoints < 0) descriptor.ExperiencePoints = 0;
                                descriptor.MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.GhoulDrainedEnergyMessage));
                            }
                            else if (creatureDescriptor.GetProperty<string>(GameConstants.Properties.SpecialAttack) == GameConstants.CreatureSpecialAttacks.Teleport)
                            {
                                if (creatureDescriptor.HasProperty(GameConstants.Properties.ItemBlocks) && descriptor.Items[creatureDescriptor.GetProperty<string>(GameConstants.Properties.ItemBlocks)] > 0)
                                {
                                    descriptor.MessageQueue.AddMessage(creatureDescriptor.GetProperty<string>(GameConstants.Properties.ItemBlockMessage));
                                }
                                else
                                {
                                    descriptor.MessageQueue.AddMessage(creatureDescriptor.GetProperty<string>(GameConstants.Properties.HitByMessage));
                                    descriptor.MapCreature.Remove();
                                    descriptor.Teleport();
                                    descriptor.MapCreature.Place();
                                }
                            }
                            else
                            {
                                descriptor.MessageQueue.AddMessage(creatureDescriptor.GetProperty<string>(GameConstants.Properties.HitByMessage));
                                descriptor.TakeDamage(damage, defendRoll);
                                if (creature.Dead)
                                {
                                    descriptor.MessageQueue.AddMessage(creatureDescriptor.GetProperty<string>(GameConstants.Properties.KilledByMessage));
                                }
                            }
                        }
                        else
                        {
                            descriptor.MessageQueue.AddMessage(creatureDescriptor.GetProperty<string>(GameConstants.Properties.MissedByMessage));
                        }
                        numberOfAttacks--;
                    }
                }
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (theCreature.Map[nextColumn][nextRow].ItemIdentifier != String.Empty)
            {
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (nextColumn == 0 || nextColumn >= theCreature.Map.Columns - 1 || nextRow == 0 || nextRow >= theCreature.Map.Columns - 1)
            {
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (((creatureDescriptor.GetProperty<string>(GameConstants.Properties.SpecialAttack) == GameConstants.CreatureSpecialAttacks.Generator)) && theGame.RandomNumberGenerator.Next(6) < 1)
            {
                string identifier = theGame.TableSet.CreatureTable.GenerateCreature(creatureDescriptor.GetProperty<string>(GameConstants.Properties.GeneratorTable), theGame.RandomNumberGenerator);
                Creature creature = new Creature(identifier, nextColumn, nextRow, theGame);
                creature.Map = theCreature.Map;
                theCreature.Map.SummonedCreatures.Add(creature);
                theCreature.Map[nextColumn][nextRow].Creature = creature;

                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
        }
        public static IMover LoadFromNode(XElement node)
        {
            return new CreatureMoveHandler();
        }
    }
}
