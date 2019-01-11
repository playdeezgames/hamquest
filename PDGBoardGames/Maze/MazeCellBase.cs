

using System.Collections.Generic;
namespace PDGBoardGames
{
    public class MazeCellBase<TWalker,TDirection,TPortal,TCellInfo>:IBoardCell
        where TWalker:IWalker<TDirection>,new()
        where TPortal:MazePortalBase,new()
        where TCellInfo:IMazeCellInfo<TCellInfo>,new()
    {
        private Dictionary<TDirection,MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>> neighbors = new Dictionary<TDirection,MazeCellBase<TWalker,TDirection,TPortal,TCellInfo>>();
        private Dictionary<TDirection,TPortal> portals;
        private TCellInfo cellInfo=new TCellInfo();

        public Dictionary<TDirection, MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>> Neighbors
        {
            get
            {
                return (neighbors);
            }
        }
        public Dictionary<TDirection, TPortal> Portals
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
                TWalker directions = new TWalker();
                int openCount = 0;
                foreach (var direction in directions.Values)
                {
                    if (Portals[direction] != null && Portals[direction].Open)
                    {
                        openCount++;
                    }
                }
                return openCount;
            }
        }
        public TCellInfo CellInfo
        {
            get
            {
                return (cellInfo);
            }
            set
            {
                cellInfo = value.Clone();
            }
        }
        public void Clear()
        {
            cellInfo.Clear();
        }
        public MazeCellBase()
        {
            TWalker directions = new TWalker();
            neighbors = new Dictionary<TDirection, MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>>();
            portals = new Dictionary<TDirection, TPortal>();
            foreach (var direction in directions.Values)
            {
                neighbors.Add(direction, null);
                portals.Add(direction, null);
            }
        }

        public object Clone()
        {
            MazeCellBase<TWalker, TDirection, TPortal, TCellInfo> result = new MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>();
            result.CellInfo = CellInfo;
            return (result);
        }


    }
}
