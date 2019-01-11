using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;


namespace HamQuestEngine
{
    public class Maze : MazeBase<Directions, int, Portal, CellInfo>, IGameClient
    {
        private Game game;
        public Game Game
        {
            get
            {
                return game;
            }
        }
        public PlayerDescriptor PlayerDescriptor;
        private void populateMaze()
        {
            int column;
            int row;
            int direction;
            Directions directions = new Directions();
            Dictionary<int, int> lockCounts = new Dictionary<int, int>();
            List<MazeCellBase<Directions, int, Portal, CellInfo>> deadEndCells = new List<MazeCellBase<Directions, int, Portal, CellInfo>>();
            List<MazeCellBase<Directions, int, Portal, CellInfo>> nonDeadEndCells = new List<MazeCellBase<Directions, int, Portal, CellInfo>>();
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    MazeCellBase<Directions, int, Portal, CellInfo> cell = this[column][row];
                    int openCount = 0;
                    for (direction = 0; direction < directions.Count; ++direction)
                    {
                        if (cell.Portals[direction] != null && cell.Portals[direction].Open)
                        {
                            openCount++;
                        }
                    }
                    int total = Game.TableSet.PropertyGroupTable.GetPropertyDescriptor("roomChance").GetProperty<int>("total");
                    int chance = Game.TableSet.PropertyGroupTable.GetPropertyDescriptor("roomChance").GetProperty<int>(string.Format("doorCount{0}", openCount));
                    if (Game.RandomNumberGenerator.Next(total) < chance)
                    {
                        cell.CellInfo.CellType = GameConstants.CellTypes.Room;
                    }
                    else
                    {
                        cell.CellInfo.CellType = GameConstants.CellTypes.Passageway;
                    }
                    if (openCount == 1)
                    {
                        deadEndCells.Add(cell);
                        for (direction = 0; direction < directions.Count; ++direction)
                        {
                            if (cell.Portals[direction] != null && cell.Portals[direction].Open)
                            {
                                cell.Portals[direction].Locked = true;
                                cell.Portals[direction].LockType = Game.TableSet.ItemTable.LockTypeGenerator.Generate(Game.RandomNumberGenerator);
                                if (lockCounts.ContainsKey(cell.Portals[direction].LockType))
                                {
                                    lockCounts[cell.Portals[direction].LockType]++;
                                }
                                else
                                {
                                    lockCounts.Add(cell.Portals[direction].LockType, 1);
                                }
                            }
                        }
                    }
                    else
                    {
                        nonDeadEndCells.Add(cell);
                    }
                    cell.CellInfo.Game = Game;
                    cell.CellInfo.Map = new Map(Game);
                    cell.CellInfo.Map.GenerateTerrain(cell);
                }
            }
            foreach (MazeCellBase<Directions, int, Portal, CellInfo> cell in deadEndCells)
            {
                for (direction = 0; direction < directions.Count; ++direction)
                {
                    Portal portal = cell.Portals[direction];
                    if (portal != null && portal.Open && portal.Locked)
                    {
                        cell.Neighbors[direction].CellInfo.Items.Add(Game.TableSet.ItemTable.GetDoorItemIdentifier(portal.LockType, directions.Opposite(direction)));
                    }
                }
            }
            foreach (int lockType in lockCounts.Keys)
            {
                int count = lockCounts[lockType];
                while (count > 0)
                {
                    count--;
                    MazeCellBase<Directions, int, Portal, CellInfo> cell = nonDeadEndCells[Game.RandomNumberGenerator.Next(nonDeadEndCells.Count)];
                    cell.CellInfo.Items.Add(Game.TableSet.ItemTable.GetKeyItemIdentifier(lockType));
                }
            }
            foreach (string itemIdentifier in Game.TableSet.ItemTable.ItemIdentifiers)
            {
                Descriptor itemDescriptor = Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
                if (itemDescriptor == null) continue;
                if (!itemDescriptor.HasProperty(GameConstants.Properties.ItemCount)) continue;
                int count = itemDescriptor.GetProperty<int>(GameConstants.Properties.ItemCount);
                while (count > 0)
                {
                    count--;
                    string placements = itemDescriptor.GetProperty<string>(GameConstants.Properties.Placement);
                    if (placements == GameConstants.Placements.Either)
                    {
                        column = Game.RandomNumberGenerator.Next(Columns);
                        row = Game.RandomNumberGenerator.Next(Rows);
                        this[column][row].CellInfo.Items.Add(itemIdentifier);
                    }
                    else
                        if (placements == GameConstants.Placements.DeadEnd)
                        {
                            deadEndCells[Game.RandomNumberGenerator.Next(deadEndCells.Count)].CellInfo.Items.Add(itemIdentifier);
                        }
                        else
                            if (placements == GameConstants.Placements.NonDeadEnd)
                            {
                                nonDeadEndCells[Game.RandomNumberGenerator.Next(nonDeadEndCells.Count)].CellInfo.Items.Add(itemIdentifier);
                            }
                }
            }
            foreach (string creatureIdentifier in Game.TableSet.CreatureTable.CreatureIdentifiers)
            {
                Descriptor creatureDescriptor = Game.TableSet.CreatureTable.GetCreatureDescriptor(creatureIdentifier);
                if (creatureDescriptor == null) continue;
                int count = creatureDescriptor.GetProperty<int>(GameConstants.Properties.CreatureCount);
                while (count > 0)
                {
                    count--;
                    string placements = creatureDescriptor.GetProperty<string>(GameConstants.Properties.Placement);
                    if (placements == GameConstants.Placements.Either)
                    {
                        column = Game.RandomNumberGenerator.Next(Columns);
                        row = Game.RandomNumberGenerator.Next(Rows);
                        this[column][row].CellInfo.Creatures.Add(creatureIdentifier);
                    }
                    else
                        if (placements == GameConstants.Placements.DeadEnd)
                        {
                            deadEndCells[Game.RandomNumberGenerator.Next(deadEndCells.Count)].CellInfo.Creatures.Add(creatureIdentifier);
                        }
                        else
                            if (placements == GameConstants.Placements.NonDeadEnd)
                            {
                                nonDeadEndCells[Game.RandomNumberGenerator.Next(nonDeadEndCells.Count)].CellInfo.Creatures.Add(creatureIdentifier);
                            }
                }
            }
            do
            {
                column = Game.RandomNumberGenerator.Next(Columns);
                row = Game.RandomNumberGenerator.Next(Rows);
            } while (deadEndCells.IndexOf(this[column][row]) != -1);
            this[column][row].CellInfo.Creatures.Add("player");
            this[column][row].CellInfo.VisitCount++;
            PlayerDescriptor.MazeColumn = column;
            PlayerDescriptor.MazeRow = row;
            foreach (string identifier in Game.TableSet.ItemTable.ItemIdentifiers)
            {
                Descriptor descriptor = Game.TableSet.ItemTable.GetItemDescriptor(identifier);
                if(descriptor == null) continue;
                if (descriptor.HasProperty(GameConstants.Properties.InitialInventory))
                {
                    int count = descriptor.GetProperty<WeightedGenerator<int>>(GameConstants.Properties.InitialInventory).Generate(Game.RandomNumberGenerator);
                    while (count > 0)
                    {
                        PlayerDescriptor.AddItem(identifier, false);
                        count--;
                    }
                }
            }
            PlayerDescriptor.AutoEquip();
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    this[column][row].CellInfo.Map.Generate(this[column][row]);
                }
            }
            PlayerDescriptor.MapCreature = Map.PlayerCreature;
            PlayerDescriptor.UpdatePathfinding();
            PlayerDescriptor.RevealTraps();
        }
        public Maze(Game theGame)
            : base(theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.MazeDimensions).GetProperty<int>(GameConstants.Properties.Columns), theGame.TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.MazeDimensions).GetProperty<int>(GameConstants.Properties.Rows))
        {
            game  = theGame;
            PlayerDescriptor = Game.TableSet.CreatureTable.GetCreatureDescriptor("player") as PlayerDescriptor;
            PlayerDescriptor.Maze = this;
            OnPostGenerate += new MazeBase<Directions, int, Portal, CellInfo>.MazeGenerationDelegate(this.populateMaze);
        }
        public void RespawnItem(string itemIdentifier)
        {
            Descriptor descriptor = Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier);
            if (descriptor.GetProperty<string>(GameConstants.Properties.Placement) == GameConstants.Placements.None) return;
            int mazeRow;
            int mazeColumn;
            bool done = false;
            while (!done)
            {
                mazeRow = Game.RandomNumberGenerator.Next(Rows);
                mazeColumn = Game.RandomNumberGenerator.Next(Columns);
                int doors = 0;
                for (int direction = Directions.North; direction <= Directions.West; ++direction)
                {
                    if (this[mazeColumn][mazeRow].Neighbors[direction] != null && this[mazeColumn][mazeRow].Portals[direction].Open)
                    {
                        doors++;
                    }
                }
                if (descriptor.GetProperty<string>(GameConstants.Properties.Placement) == GameConstants.Placements.DeadEnd && doors != 1)
                {
                    done = false;
                    continue;
                }
                if (descriptor.GetProperty<string>(GameConstants.Properties.Placement) == GameConstants.Placements.NonDeadEnd && doors == 1)
                {
                    done = false;
                    continue;
                }
                int mapColumn;
                int mapRow;
                done = false;
                for (mapColumn = 0; !done && mapColumn < this[mazeColumn][mazeRow].CellInfo.Map.Columns; ++mapColumn)
                {
                    for (mapRow = 0; !done && mapRow < this[mazeColumn][mazeRow].CellInfo.Map.Rows; ++mapRow)
                    {
                        if (
                            (Game.TableSet.TerrainTable.GetTerrainDescriptor(this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].TerrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable)) &&
                            (this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].ItemIdentifier == String.Empty) &&
                            (this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].Creature == null)
                            )
                        {
                            done = true;
                        }
                    }
                }
                if (!done) continue;
                do
                {
                    mapColumn = Game.RandomNumberGenerator.Next(this[mazeColumn][mazeRow].CellInfo.Map.Columns);
                    mapRow = Game.RandomNumberGenerator.Next(this[mazeColumn][mazeRow].CellInfo.Map.Rows);
                }
                while (
                    (!Game.TableSet.TerrainTable.GetTerrainDescriptor(this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].TerrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable)) ||
                    (this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].ItemIdentifier != String.Empty) ||
                    (this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].Creature != null)
                );
                this[mazeColumn][mazeRow].CellInfo.Map[mapColumn][mapRow].ItemIdentifier = itemIdentifier;
            }
        }
        public void SpawnMonsters(float fraction)
        {
            int spawnCount = 0;
            int column;
            int row;
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    if (this[column][row].CellInfo.VisitCount>0)
                    {
                        spawnCount += this[column][row].CellInfo.Map.SpawnCount;
                    }
                }
            }
            spawnCount = (int)((float)spawnCount * fraction);
            while (spawnCount > 0)
            {
                column = Game.RandomNumberGenerator.Next(Columns);
                row = Game.RandomNumberGenerator.Next(Rows);
                if (this[column][row].CellInfo.VisitCount > 0 && this[column][row].CellInfo.Map.HasTrap)
                {
                    Map map = this[column][row].CellInfo.Map;
                    int mapColumn;
                    int mapRow;
                    string itemIdentifier;
                    do
                    {
                        mapColumn = Game.RandomNumberGenerator.Next(map.Columns);
                        mapRow = Game.RandomNumberGenerator.Next(map.Rows);
                        itemIdentifier = map[mapColumn][mapRow].ItemIdentifier;
                    } while (itemIdentifier == String.Empty || !Game.TableSet.ItemTable.GetItemDescriptor(itemIdentifier).HasTag(GameConstants.Tags.Spawns));
                    map[mapColumn][mapRow].ItemIdentifier = String.Empty;
                    this[column][row].CellInfo.Items.Remove(itemIdentifier);
                    Creature creature = new Creature(Game.TableSet.CreatureTable.GenerateCreature(GameConstants.Properties.SpawnWeight,Game.RandomNumberGenerator), mapColumn, mapRow, Game);
                    creature.Map = map;
                    map.Creatures.Add(creature);
                    map[mapColumn][mapRow].Creature = creature;
                    spawnCount--;
                }
            }
        }
    }
}
