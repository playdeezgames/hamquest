using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;


namespace HamQuestEngine
{
    public class MapCell : BoardCellBase
    {
        public string TerrainIdentifier;
        public string ItemIdentifier
        {
            get
            {
                return theItemIdentifier;
            }
            set
            {
                if (value == null)
                {
                    throw new Exception();
                }
                theItemIdentifier = value;
            }
        }
        private string theItemIdentifier = String.Empty;
        public Creature Creature = null;
        public int PathfindingValue = 0;
        public override void Clear()
        {
            ItemIdentifier = String.Empty;
            TerrainIdentifier = "0";
        }
        public object Clone()
        {
            MapCell result = new MapCell();
            result.TerrainIdentifier = this.TerrainIdentifier;
            result.ItemIdentifier = this.ItemIdentifier;
            //TODO fix DDMapCreature cloning
            return (object)result;
        }
        public MapCell()
        {
        }


    }
}
