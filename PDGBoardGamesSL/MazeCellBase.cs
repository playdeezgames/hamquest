using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;


namespace PDGBoardGames
{
    public class MazeCellBase<DirectionsType,PortalType,CellInfoType>:BoardCellBase
        where DirectionsType:DirectionsBase,new()
        where PortalType:MazePortalBase,new()
        where CellInfoType:MazeCellInfoBase,new()
    {
        private MazeCellBase<DirectionsType, PortalType, CellInfoType>[] neighbors;
        private PortalType[] portals;
        private CellInfoType cellInfo=new CellInfoType();

        public MazeCellBase<DirectionsType, PortalType, CellInfoType>[] Neighbors
        {
            get
            {
                return (neighbors);
            }
        }
        public PortalType[] Portals
        {
            get
            {
                return (portals);
            }
        }
        public int OpenPortalCount
        {
            get
            {
                DirectionsType directions = new DirectionsType();
                int openCount = 0;
                for (int direction = 0; direction < directions.Count; ++direction)
                {
                    if (Portals[direction] != null && Portals[direction].Open)
                    {
                        openCount++;
                    }
                }
                return openCount;
            }
        }
        public CellInfoType CellInfo
        {
            get
            {
                return (cellInfo);
            }
            set
            {
                cellInfo = (CellInfoType)value.Clone();
            }
        }
        public override void Clear()
        {
            cellInfo.Clear();
        }
        public MazeCellBase()
        {
            DirectionsType directions = new DirectionsType();
            neighbors = new MazeCellBase<DirectionsType, PortalType, CellInfoType>[directions.Count];
            portals = new PortalType[directions.Count];
        }

        public object Clone()
        {
            MazeCellBase<DirectionsType, PortalType, CellInfoType> result = new MazeCellBase<DirectionsType, PortalType, CellInfoType>();
            result.CellInfo = CellInfo;
            return (result);
        }


    }
}
