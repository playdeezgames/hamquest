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
    public class PlayerMoveHandler:IMover
    {
        public void DoMove(Creature theCreature, ref int nextColumn, ref int nextRow,Game theGame)
        {
            PlayerDescriptor playerDescriptor = theGame.TableSet.CreatureTable.GetCreatureDescriptor(theCreature.CreatureIdentifier) as PlayerDescriptor;
            playerDescriptor.EatIfNeeded();
            if (nextColumn < 0)
            {
                playerDescriptor.MazeColumn--;
                Map.PlayerCreature = null;
                theCreature.Map = playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.Map;
                Map.PlayerCreature = theCreature;
                nextColumn += theCreature.Map.Columns;

                playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.AddVisit();
            }
            else if (nextRow < 0)
            {
                playerDescriptor.MazeRow--;
                Map.PlayerCreature = null;
                theCreature.Map = playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.Map;
                Map.PlayerCreature = theCreature;
                nextRow += theCreature.Map.Rows;

                playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.AddVisit();
            }
            else if (nextColumn >= theCreature.Map.Columns)
            {
                playerDescriptor.MazeColumn++;
                Map.PlayerCreature = null;
                theCreature.Map = playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.Map;
                Map.PlayerCreature = theCreature;
                nextColumn -= theCreature.Map.Columns;

                playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.AddVisit();
            }
            else if (nextRow >= theCreature.Map.Rows)
            {
                playerDescriptor.MazeRow++;
                Map.PlayerCreature = null;
                theCreature.Map = playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.Map;
                Map.PlayerCreature = theCreature;
                nextRow -= theCreature.Map.Rows;

                playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.AddVisit();
            }
            else if (theGame.TableSet.TerrainTable.GetTerrainDescriptor(theCreature.Map[nextColumn][nextRow].TerrainIdentifier).GetProperty<IBumpHandler>(GameConstants.Properties.BumpHandler).Bump(theGame.TableSet.TerrainTable.GetTerrainDescriptor(theCreature.Map[nextColumn][nextRow].TerrainIdentifier), theCreature) != BumpResult.Allow)
            {
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (theCreature.Map[nextColumn][nextRow].Creature != null)
            {
                Creature creature = theCreature.Map[nextColumn][nextRow].Creature;
                Descriptor descriptor = theGame.TableSet.CreatureTable.GetCreatureDescriptor(creature.CreatureIdentifier);
                int damage = theCreature.RollAttack() - creature.RollDefend();
                if (damage > 0)
                {
                    creature.Wounds += damage;
                    creature.BeenHit = true;
                    playerDescriptor.CheckForWeaponBreakage(damage);
                    if (creature.Dead)
                    {
                        Descriptor creatureDescriptor = theGame.TableSet.CreatureTable.GetCreatureDescriptor(creature.CreatureIdentifier);
                        WeightedGenerator<string> generator = creatureDescriptor.GetProperty<WeightedGenerator<string>>(GameConstants.Properties.ItemDrops);
                        string identifier = generator.Generate(theGame.RandomNumberGenerator);
                        theCreature.Map[creature.Column][creature.Row].ItemIdentifier = identifier;

                        playerDescriptor.MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.KillMessage));
                        if (!creature.Summoned)
                        {
                            playerDescriptor.AddExperience(descriptor.GetProperty<int>(GameConstants.Properties.ExperiencePoints));
                        }
                    }
                    else
                    {
                        playerDescriptor.MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.HitMessage));
                    }
                }
                else
                {
                    playerDescriptor.MessageQueue.AddMessage(descriptor.GetProperty<string>(GameConstants.Properties.MissMessage));
                }
                nextColumn = theCreature.Column;
                nextRow = theCreature.Row;
            }
            else if (theCreature.Map[nextColumn][nextRow].ItemIdentifier != String.Empty)
            {
                Descriptor itemDescriptor = theGame.TableSet.ItemTable.GetItemDescriptor(theCreature.Map[nextColumn][nextRow].ItemIdentifier);
                if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Door)
                {
                    CountedCollection<string> itemUnlocks = itemDescriptor.GetProperty<CountedCollection<string>>(GameConstants.Properties.ItemUnlocks);
                    bool unlocked = false;
                    foreach (string identifier in itemUnlocks.Identifiers)
                    {
                        if (playerDescriptor.Items[identifier] >= itemUnlocks[identifier])
                        {
                            playerDescriptor.Items.Remove(identifier, itemUnlocks[identifier]);
                            unlocked = true;
                            playerDescriptor.MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                            playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].Portals[itemDescriptor.GetProperty<int>(GameConstants.Properties.Direction)].Locked = false;
                            break;
                        }
                    }
                    if (!unlocked)
                    {
                        playerDescriptor.MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.BumpMessage));
                        nextColumn = theCreature.Column;
                        nextRow = theCreature.Row;
                    }
                }
                else if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Portal)
                {
                    if (itemDescriptor.HasProperty(GameConstants.Properties.ItemBlocks) && playerDescriptor.Items[itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemBlocks)] > 0)
                    {
                        playerDescriptor.MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemBlockMessage));
                        nextColumn = theCreature.Column;
                        nextRow = theCreature.Row;
                    }
                    else
                    {
                        theCreature.Map[nextColumn][nextRow].ItemIdentifier = String.Empty;
                        playerDescriptor.MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.PickUpMessage));
                        playerDescriptor.Teleport();
                        nextColumn = theCreature.Column;
                        nextRow = theCreature.Row;
                    }
                }
                else if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Shop)
                {
                    if (theCreature.Map.HasCreature)
                    {
                        playerDescriptor.MessageQueue.AddMessage(itemDescriptor.GetProperty<string>(GameConstants.Properties.BumpMessage));
                        nextColumn = theCreature.Column;
                        nextRow = theCreature.Row;
                    }
                    else
                    {
                        playerDescriptor.ShopState = new ShopState(itemDescriptor, playerDescriptor, theGame);
                        for (int column = 0; column < playerDescriptor.Maze.Columns; ++column)
                        {
                            for (int row = 0; row < playerDescriptor.Maze.Rows; ++row)
                            {
                                if (playerDescriptor.Maze[column][row].CellInfo.VisitCount > 0)
                                {
                                    playerDescriptor.Maze[column][row].CellInfo.AddVisits(7);
                                }
                            }
                        }
                        playerDescriptor.Maze.RespawnItem(theCreature.Map[nextColumn][nextRow].ItemIdentifier);
                        theCreature.Map[nextColumn][nextRow].ItemIdentifier = String.Empty;
                    }
                }
                else if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Exit)
                {
                    bool success = false;
                    if (playerDescriptor.Items["Amulet"]!=0)
                    {
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.GetProperty<string>(GameConstants.Properties.CannotExitWithAmuletMessage));
                    }
                    else if (playerDescriptor.QuestItems == theGame.TableSet.ItemTable.QuestItemCount && playerDescriptor.Items["RainbowKey"] > 0)
                    {
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.GetProperty<string>(GameConstants.Properties.WonGameMessage));
                        success = true;
                    }
                    else if (playerDescriptor.QuestItems == theGame.TableSet.ItemTable.QuestItemCount)
                    {
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.GetProperty<string>(GameConstants.Properties.NeedRainbowKeyMessage));
                    }
                    else
                    {
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.GetProperty<string>(GameConstants.Properties.NeedCompletedMegahamMessage));
                    }
                    if (success)
                    {
                        playerDescriptor.PlayerState = GameConstants.PlayerStates.Win;
                    }
                    else
                    {
                        nextColumn = theCreature.Column;
                        nextRow = theCreature.Row;
                    }
                }
                else if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Chest)
                {
                    //opened chest
                    playerDescriptor.AddItem(theCreature.Map[nextColumn][nextRow].ItemIdentifier);
                    theCreature.Map[nextColumn][nextRow].ItemIdentifier = itemDescriptor.GetProperty<WeightedGenerator<string>>(GameConstants.Properties.GeneratedItem).Generate(theGame.RandomNumberGenerator);
                    nextColumn = theCreature.Column;
                    nextRow = theCreature.Row;
                }
                else
                {
                    
                    playerDescriptor.AddItem(theCreature.Map[nextColumn][nextRow].ItemIdentifier);
                }
                theCreature.Map[nextColumn][nextRow].ItemIdentifier = String.Empty;
            }
        }
        public PlayerMoveHandler()
        {
        }
        public static IMover LoadFromNode(XElement node)
        {
            return new PlayerMoveHandler();
        }
    }
}
