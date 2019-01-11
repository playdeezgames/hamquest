using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;


namespace HamQuestEngine
{

    public class Map:Board<MapCell>,IGameClient
    {
        private Game game;
        public Game Game
        {
            get
            {
                return game;
            }
        }

        private const string PassagewayBaseFilename = "pway{0}.cqm";
        private const string PassagewayDoorFilename = "pwaydoor{0}.cqm";

        private const string RoomBaseFilename = "room.cqm";
        private const string RoomOpenFilename = "roomopen{0}.cqm";
        private const string RoomDoorFilename = "roomdoor{0}.cqm";

        private static Creature playerCreature = null;
        public static Creature PlayerCreature
        {
            get
            {
                return (playerCreature);
            }
            set
            {
                playerCreature = value;
            }
        }
        private List<Creature> creatures = new List<Creature>();
        private List<Creature> summonedCreatures = new List<Creature>();
        public List<Creature> Creatures
        {
            get
            {
                return (creatures);
            }
        }
        public List<Creature> SummonedCreatures
        {
            get
            {
                return summonedCreatures;
            }
        }
        private string[] GetMapFileList(MazeCellBase<Directions, Portal, CellInfo> cell)
        {
            List<string> result = new List<string>();
            Directions directions = new Directions();
            if (cell.CellInfo.CellType == GameConstants.CellTypes.Passageway)
            {
                int direction;
                int pwaybase = 0;
                bool[] locked = new bool[directions.Count];
                for (direction = directions.Count - 1; direction >= 0; --direction)
                {
                    Portal portal = cell.Portals[direction];
                    locked[direction] = false;
                    if (portal != null)
                    {
                        if (portal.Open)
                        {
                            pwaybase += (1 << direction);
                            if (portal.Locked)
                            {
                                locked[direction] = true;
                            }
                        }
                    }
                }
                result.Add(string.Format(PassagewayBaseFilename, pwaybase));
                for (direction = 0; direction < directions.Count; ++direction)
                {
                    if (locked[direction])
                    {
                        result.Add(string.Format(PassagewayDoorFilename, direction));
                    }
                }
            }
            else if (cell.CellInfo.CellType == GameConstants.CellTypes.Room)
            {
                result.Add(RoomBaseFilename);
                int direction;
                for (direction = directions.Count - 1; direction >= 0; --direction)
                {
                    Portal portal = cell.Portals[direction];
                    if (portal != null)
                    {
                        if (portal.Open)
                        {
                            if (portal.Locked)
                            {
                                result.Add(string.Format(RoomDoorFilename, direction));
                            }
                            else
                            {
                                result.Add(string.Format(RoomOpenFilename, direction));
                            }
                        }
                    }
                }
            }
            return (result.ToArray());
        }
        public void GenerateTerrain(MazeCellBase<Directions, Portal, CellInfo> mazeCell)
        {
            string[] fileList = GetMapFileList(mazeCell);
            CQMFile cqm = null;
            foreach (string fileName in fileList)
            {
                if (cqm == null)
                {
                    cqm = CQMLoader.LoadFromFile("/HamQuestSLClient;component/maps/" + fileName);
                }
                else
                {
                    cqm.Blend(CQMLoader.LoadFromFile("/HamQuestSLClient;component/maps/" + fileName), 0, 0, 255);
                }
            }
            int column;
            int row;
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    byte cellValue = cqm.GetCellValue((byte)column, (byte)row);
                    this[column][row].TerrainIdentifier = cellValue.ToString();
                }
            }
        }
        public void Generate(MazeCellBase<Directions, Portal, CellInfo> mazeCell)
        {
            GenerateTerrain(mazeCell);
            int column;
            int row;
            foreach (string itemIdentifier in mazeCell.CellInfo.Items.Identifiers)
            {
                uint count = mazeCell.CellInfo.Items[itemIdentifier];
                while (count > 0)
                {
                    count--;
                    int tally = 0;
                    Descriptor itemDescriptor = Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                    do
                    {
                        column = itemDescriptor.GetProperty<WeightedGenerator<int>>(GameConstants.Properties.XGenerator).Generate(Game.RandomNumberGenerator);
                        row = itemDescriptor.GetProperty<WeightedGenerator<int>>(GameConstants.Properties.YGenerator).Generate(Game.RandomNumberGenerator);
                        tally++;
                        if (tally > 100)
                        {
                            System.Diagnostics.Debug.WriteLine("blah");
                        }
                    } while (this[column][row].ItemIdentifier != String.Empty || !Game.TableSet.TerrainTable.GetTerrainDescriptor(this[column][row].TerrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable));
                    bool done = true;
                    string theItemIdentifier = itemIdentifier;
                    do
                    {
                        done = true;
                        string newItemIdentifier = itemDescriptor.GetProperty<WeightedGenerator<string>>(GameConstants.Properties.SpawnAs).Generate(Game.RandomNumberGenerator);
                        if (newItemIdentifier != theItemIdentifier)
                        {
                            done = false;
                            theItemIdentifier = newItemIdentifier;
                            itemDescriptor = Game.TableSet.ItemTable.GetItemDescriptor(theItemIdentifier);
                        }
                    }
                    while (!done);
                    this[column][row].ItemIdentifier = theItemIdentifier;
                }
            }
            foreach (string creatureIdentifier in mazeCell.CellInfo.Creatures.Identifiers)
            {
                uint count = mazeCell.CellInfo.Creatures[creatureIdentifier];
                Descriptor creatureDescriptor = Game.TableSet.CreatureTable.GetCreatureDescriptor(creatureIdentifier);
                while (count > 0)
                {
                    count--;
                    do
                    {
                        column = Game.RandomNumberGenerator.Next(Columns - 2) + 1;
                        row = Game.RandomNumberGenerator.Next(Rows - 2) + 1;
                    } while (!Game.TableSet.TerrainTable.GetTerrainDescriptor(this[column][row].TerrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable) || this[column][row].ItemIdentifier != String.Empty || this[column][row].Creature != null);
                    Creature creature = new Creature(creatureIdentifier,column, row,Game);
                    this[column][row].Creature = creature;
                    creature.Map = this;
                    if (creatureIdentifier == "player")
                    {
                        playerCreature = creature;
                    }
                    else
                    {
                        Creatures.Add(creature);
                    }
                }
            }
        }
        public void RemoveDeadCreatures()
        {
            List<Creature> deadList = new List<Creature>();
            foreach (Creature creature in Creatures)
            {
                if (creature.Dead)
                {
                    deadList.Add(creature);
                }
            }
            foreach (Creature creature in deadList)
            {
                creature.Remove();
                Creatures.Remove(creature);
            }
        }
        public void MoveCreatures(float steps)
        {
            Directions directions = new Directions();
            foreach (Creature creature in Creatures)
            {
                if (!creature.Dead)
                {
                    creature.Steps += (float)Game.TableSet.CreatureTable.GetCreatureDescriptor(creature.CreatureIdentifier).GetProperty<IStatisticHolder>("speed").Value * steps;
                    while (creature.Steps >= 1.0f)
                    {
                        creature.Steps -= 1.0f;
                        if (playerCreature != null)
                        {
                            //START OF CREATURE MOVEMENT CODE
                            Descriptor descriptor = Game.TableSet.CreatureTable.GetCreatureDescriptor(creature.CreatureIdentifier);

                            if (!descriptor.GetProperty<WeightedGenerator<bool>>(GameConstants.Properties.MoraleRoll).Generate(Game.RandomNumberGenerator))
                            {
                                creature.Move(Game.RandomNumberGenerator.Next(directions.Count));
                            }
                            else
                            {
                                int lowestValue = int.MaxValue;
                                int chosenDirection = directions.Count;
                                for (int direction = 0; direction < directions.Count; ++direction)
                                {
                                    int nextColumn = directions.GetNextColumn(creature.Column, creature.Row, direction);
                                    int nextRow = directions.GetNextRow(creature.Column, creature.Row, direction);
                                    if (nextColumn < 0 || nextRow < 0 || nextColumn >= Columns || nextRow >= Rows) continue;
                                    if (this[nextColumn][nextRow].PathfindingValue == int.MaxValue) continue;
                                    if (this[nextColumn][nextRow].PathfindingValue < lowestValue)
                                    {
                                        lowestValue = this[nextColumn][nextRow].PathfindingValue;
                                        chosenDirection = direction;
                                    }
                                }
                                if (chosenDirection < directions.Count)
                                {
                                    creature.Move(chosenDirection);
                                }
                            }
                            //END OF CREATURE MOVEMENT CODE
                        }
                    }
                }
            }
            foreach (Creature creature in SummonedCreatures)
            {
                creature.Summoned = true;
                Creatures.Add(creature);
            }
            SummonedCreatures.Clear();


        }
        public Map(Game theGame)
            : base(theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.MapDimensions).GetProperty<int>(GameConstants.Properties.Columns), theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.MapDimensions).GetProperty<int>(GameConstants.Properties.Rows))
        {
            game = theGame;
        }
        public bool HasCreature
        {
            get
            {
                for (int column = 0; column < Columns; ++column)
                {
                    for (int row = 0; row < Rows; ++row)
                    {
                        if (this[column][row].Creature != null && this[column][row].Creature != Map.PlayerCreature)
                        {
                            return true;
                        }
                    }
                }
                return false;
            }
        }
        public bool HasSpawn
        {
            get
            {
                for (int column = 0; column < Columns; ++column)
                {
                    for (int row = 0; row < Rows; ++row)
                    {
                        string identifier = this[column][row].ItemIdentifier;
                        if (identifier != String.Empty && Game.TableSet.ItemTable.GetItemDescriptor(identifier).HasTag(GameConstants.Tags.Spawns))
                        {
                            return true;
                        }
                    }
                }
                return false;
            }
        }
        public bool HasTrap
        {
            get
            {
                for (int column = 0; column < Columns; ++column)
                {
                    for (int row = 0; row < Rows; ++row)
                    {
                        string identifier = this[column][row].ItemIdentifier;
                        if (identifier != String.Empty && Game.TableSet.ItemTable.GetItemDescriptor(identifier).HasTag(GameConstants.Tags.Trap))
                        {
                            return true;
                        }
                    }
                }
                return false;
            }
        }
        public int SpawnCount
        {
            get
            {
                int count = 0;
                for (int column = 0; column < Columns; ++column)
                {
                    for (int row = 0; row < Rows; ++row)
                    {
                        string identifier = this[column][row].ItemIdentifier;
                        if (identifier != String.Empty && Game.TableSet.ItemTable.GetItemDescriptor(identifier).HasTag(GameConstants.Tags.Spawns))
                        {
                            count++;
                        }
                    }
                }
                return count;
            }
        }
        public int TrapCount
        {
            get
            {
                int count = 0;
                for (int column = 0; column < Columns; ++column)
                {
                    for (int row = 0; row < Rows; ++row)
                    {
                        string identifier = this[column][row].ItemIdentifier;
                        if (identifier != String.Empty && Game.TableSet.ItemTable.GetItemDescriptor(identifier).GetProperty<bool>("isTrap"))
                        {
                            count++;
                        }
                    }
                }
                return count;
            }
        }
        public void RevealHiddens(int column, int row)
        {
            if (column >= 0 && row >= 0 && column < Columns && row < Rows)
            {
                string itemIdentifier = this[column][row].ItemIdentifier;
                if (itemIdentifier != String.Empty)
                {
                    Descriptor itemDescriptor = Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                    if (itemDescriptor.GetProperty<string>(GameConstants.Properties.ItemType) == GameConstants.ItemTypes.Hidden)
                    {
                        this[column][row].ItemIdentifier = itemDescriptor.GetProperty<string>("hidden-item-identifier");
                    }
                }
            }
        }
        public bool HasItem
        {
            get
            {
                return HasItemTag("item");
            }
        }
        public bool HasItemTag(string tag)
        {
            for (int column = 0; column < Columns; ++column)
            {
                for (int row = 0; row < Rows; ++row)
                {
                    string identifier = this[column][row].ItemIdentifier;
                    if (!string.IsNullOrEmpty(identifier) && Game.TableSet.ItemTable.GetItemDescriptor(identifier).HasTag(tag))
                    {
                        return true;
                    }
                }
            }
            return false;
        }
        public bool HasPortal
        {
            get
            {
                return HasItemTag(GameConstants.Tags.Portal);
            }
        }
        public bool HasQuest
        {
            get
            {
                return HasItemTag(GameConstants.Tags.Quest);
            }
        }
        public bool HasExit
        {
            get
            {
                return HasItemTag(GameConstants.Tags.Exit);
            }
        }
    }
}
