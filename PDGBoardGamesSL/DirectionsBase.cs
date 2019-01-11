using System;
using System.Collections.Generic;
using System.Text;

namespace PDGBoardGames
{
    public abstract class DirectionsBase
    {
        public abstract int Count { get;}
        public abstract int Opposite(int direction);
        public abstract int GetNextColumn(int startColumn, int startRow, int direction);
        public abstract int GetNextRow(int startColumn, int startRow, int direction);
    }
}
