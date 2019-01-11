using System.Collections.Generic;
using System.Linq;

namespace PDGBoardGames
{
    public class MazeBase<TWalker, TDirection, TPortal, TCellInfo> : Board<MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>>
        where TWalker:IWalker<TDirection>,new()
        where TPortal:MazePortalBase,new()
        where TCellInfo:IMazeCellInfo<TCellInfo>,new()
    {
        public delegate void MazeGenerationDelegate();
        public event MazeGenerationDelegate OnPostGenerate;
        private List<TPortal> portals= new List<TPortal>();
        public IEnumerable<TPortal> Portals
        {
            get
            {
                return portals;
            }
        }
        public MazeBase(int theColumns, int theRows)
            : base(theColumns, theRows)
        {
            int column;
            int row;
            int neighborColumn;
            int neighborRow;
            MazeCellBase<TWalker, TDirection, TPortal, TCellInfo> cell;
            MazeCellBase<TWalker, TDirection, TPortal, TCellInfo> neighborCell;
            TWalker directions = new TWalker();
            TPortal portal;
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    cell = this[column][row];
                    foreach (var direction in directions.Values)
                    {
                        if (cell.Neighbors[direction] == null)
                        {
                            neighborColumn = directions.GetNextColumn(column, row, direction);
                            neighborRow = directions.GetNextRow(column, row, direction);
                            var oppositeDirection = directions.Opposite(direction);
                            if (neighborColumn >= 0 && neighborRow >= 0 && neighborColumn < Columns && neighborRow < Rows)
                            {
                                neighborCell = this[neighborColumn][neighborRow];
                                cell.Neighbors[direction] = neighborCell;
                                portal = new TPortal();
                                cell.Portals[direction] = portal;
                                neighborCell.Neighbors[oppositeDirection] = cell;
                                neighborCell.Portals[oppositeDirection] = portal;
                                this.portals.Add(portal);
                            }
                        }
                    }
                }
            }
        }
        public override void Clear()
        {
            base.Clear();
            foreach (TPortal portal in Portals)
            {
                portal.Clear();
            }
        }
        /// <summary>
        /// GeneratorState
        /// This one stays an enum!
        /// </summary>
        private enum GeneratorState
        {
            Outside,
            Frontier,
            Inside
        }
        public void Generate(IRandomNumberGenerator theRandomNumberGenerator)
        {
            Clear();
            Dictionary<MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>, GeneratorState> generatorStates = new Dictionary<MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>, GeneratorState>();
            List<MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>> frontierCells = new List<MazeCellBase<TWalker, TDirection, TPortal, TCellInfo>>(Columns * Rows);
            MazeCellBase<TWalker, TDirection, TPortal, TCellInfo> cell;
            MazeCellBase<TWalker, TDirection, TPortal, TCellInfo> neighborCell;
            int column;
            int row;
            TWalker directions = new TWalker();
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    generatorStates.Add(this[column][row], GeneratorState.Outside);
                }
            }
            cell = this[theRandomNumberGenerator.Next(Columns)][theRandomNumberGenerator.Next(Rows)];
            generatorStates[cell] = GeneratorState.Inside;
            foreach (var direction in directions.Values)
            {
                neighborCell = cell.Neighbors[direction];
                if (neighborCell != null)
                {
                    frontierCells.Add(neighborCell);
                    generatorStates[neighborCell] = GeneratorState.Frontier;
                }
            }
            while (frontierCells.Count > 0)
            {
                TDirection direction;
                cell = frontierCells[theRandomNumberGenerator.Next(frontierCells.Count)];
                frontierCells.Remove(cell);
                generatorStates[cell] = GeneratorState.Inside;
                do
                {
                    direction = directions.Values.ToArray()[theRandomNumberGenerator.Next(directions.Count)];
                    neighborCell = cell.Neighbors[direction];
                }while(neighborCell == null || generatorStates[neighborCell]!=GeneratorState.Inside);
                cell.Portals[direction].Open = true;
                foreach (var chosendirection in directions.Values)
                {
                    neighborCell = cell.Neighbors[chosendirection];
                    if (neighborCell != null && generatorStates[neighborCell] == GeneratorState.Outside)
                    {
                        frontierCells.Add(neighborCell);
                        generatorStates[neighborCell] = GeneratorState.Frontier;
                    }
                }
            }
            if (OnPostGenerate != null)
            {
                OnPostGenerate();
            }
        }
    }
}
