using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;


namespace HamQuestEngine
{
    public class CellInfo : IMazeCellInfo<CellInfo>, IGameClient
    {
        private Game game;
        public Game Game
        {
            get
            {
                return game;
            }
            set
            {
                game = value;
            }
        }
        private string cellType = GameConstants.CellTypes.Passageway;
        public CountedCollection<string> Creatures = new CountedCollection<string>();
        public CountedCollection<string> Items = new CountedCollection<string>();
        public int VisitCount = 0;
        public Map Map = null;
        public string CellType
        {
            get
            {
                return (cellType);
            }
            set
            {
                cellType = value;
            }
        }
        public bool IsRoom
        {
            get
            {
                return CellType == GameConstants.CellTypes.Room;
            }
        }
        public CellInfo()
            : base()
        {
        }
        public CellInfo Clone()
        {
            CellInfo result = new CellInfo();
            result.CellType = this.CellType;
            return (result);
        }
        public void AddVisits(int theVisitCount)
        {
            while (theVisitCount > 0)
            {
                AddVisit();
                theVisitCount--;
            }
        }
        public void AddVisit()
        {
            WanderingMonsterCheck();
            VisitCount++;
        }
        private void WanderingMonsterCheck()
        {
            int roll = Game.RandomNumberGenerator.Next(1, 6) + Game.RandomNumberGenerator.Next(1, 6);
            if (roll <= VisitCount - 1)
            {
                VisitCount -= roll;
                Map map = Map;
                int mapColumn;
                int mapRow;
                string itemIdentifier;
                string terrainIdentifier;
                do
                {
                    mapColumn = Game.RandomNumberGenerator.Next(1, map.Columns - 1);
                    mapRow = Game.RandomNumberGenerator.Next(1, map.Rows - 1);
                    itemIdentifier = map[mapColumn][mapRow].ItemIdentifier;
                    terrainIdentifier = map[mapColumn][mapRow].TerrainIdentifier;
                } while (itemIdentifier != String.Empty || !Game.TableSet.TerrainTable.GetTerrainDescriptor(terrainIdentifier).GetProperty<bool>(GameConstants.Properties.Passable) || map[mapColumn][mapRow].Creature != null);
                Creature creature = new Creature(Game.TableSet.CreatureTable.GenerateCreature(GameConstants.Properties.SpawnWeight,Game.RandomNumberGenerator), mapColumn, mapRow,Game);
                creature.Map = map;
                map.SummonedCreatures.Add(creature);
                map[mapColumn][mapRow].Creature = creature;
            }
        }

        public void Clear()
        {
        }
    }
}
