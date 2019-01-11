using System;
using System.Collections.Generic;
using System.Text;


namespace PDGBoardGames
{
    public class MazeBase<DirectionsType,PortalType,CellInfoType>:Board<MazeCellBase<DirectionsType,PortalType,CellInfoType>>
        where DirectionsType:DirectionsBase,new()
        where PortalType:MazePortalBase,new()
        where CellInfoType:MazeCellInfoBase,new()
    {
        public delegate void MazeGenerationDelegate();
        public event MazeGenerationDelegate OnPostGenerate;
        private List<PortalType> portals= new List<PortalType>();
        public PortalType[] Portals
        {
            get
            {
                return (portals.ToArray());
            }
        }
        public MazeBase(int theColumns, int theRows)
            : base(theColumns, theRows)
        {
            int column;
            int row;
            int neighborColumn;
            int neighborRow;
            int direction;
            int oppositeDirection;
            MazeCellBase<DirectionsType, PortalType, CellInfoType> cell;
            MazeCellBase<DirectionsType, PortalType, CellInfoType> neighborCell;
            DirectionsType directions = new DirectionsType();
            PortalType portal;
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    cell = this[column][row];
                    for (direction = 0; direction < directions.Count; ++direction)
                    {
                        if (cell.Neighbors[direction] == null)
                        {
                            neighborColumn = directions.GetNextColumn(column, row, direction);
                            neighborRow = directions.GetNextRow(column, row, direction);
                            oppositeDirection = directions.Opposite(direction);
                            if (neighborColumn >= 0 && neighborRow >= 0 && neighborColumn < Columns && neighborRow < Rows)
                            {
                                neighborCell = this[neighborColumn][neighborRow];
                                cell.Neighbors[direction] = neighborCell;
                                portal = new PortalType();
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
            foreach (PortalType portal in Portals)
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
            Dictionary<MazeCellBase<DirectionsType, PortalType, CellInfoType>, GeneratorState> generatorStates = new Dictionary<MazeCellBase<DirectionsType, PortalType, CellInfoType>, GeneratorState>();
            List<MazeCellBase<DirectionsType, PortalType, CellInfoType>> frontierCells = new List<MazeCellBase<DirectionsType, PortalType, CellInfoType>>(Columns * Rows);
            MazeCellBase<DirectionsType, PortalType, CellInfoType> cell;
            MazeCellBase<DirectionsType, PortalType, CellInfoType> neighborCell;
            int column;
            int row;
            int direction;
            DirectionsType directions = new DirectionsType();
            for (column = 0; column < Columns; ++column)
            {
                for (row = 0; row < Rows; ++row)
                {
                    generatorStates.Add(this[column][row], GeneratorState.Outside);
                }
            }
            cell = this[theRandomNumberGenerator.Next(Columns)][theRandomNumberGenerator.Next(Rows)];
            generatorStates[cell] = GeneratorState.Inside;
            for (direction = 0; direction < directions.Count; ++direction)
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
                cell = frontierCells[theRandomNumberGenerator.Next(frontierCells.Count)];
                frontierCells.Remove(cell);
                generatorStates[cell] = GeneratorState.Inside;
                do
                {
                    direction = theRandomNumberGenerator.Next(directions.Count);
                    neighborCell = cell.Neighbors[direction];
                }while(neighborCell == null || generatorStates[neighborCell]!=GeneratorState.Inside);
                cell.Portals[direction].Open = true;
                for (direction = 0; direction < directions.Count; ++direction)
                {
                    neighborCell = cell.Neighbors[direction];
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
