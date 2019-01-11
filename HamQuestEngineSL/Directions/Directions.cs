using System;
using System.Collections.Generic;
using System.Text;
using PDGBoardGames;


namespace HamQuestEngine
{
    public class Directions:DirectionsBase
    {
        public const int North = 0;
        public const int East = 1;
        public const int South = 2;
        public const int West = 3;

        public override int Count
        {
            get { return (4); }
        }

        public override int Opposite(int direction)
        {
            return ((direction + 2) % 4);
        }

        public override int GetNextColumn(int startColumn, int startRow, int direction)
        {
            switch (direction % 4)
            {
                case 1:
                    return (startColumn + 1);
                case 3:
                    return (startColumn - 1);
                default:
                    return (startColumn);
            }
        }

        public override int GetNextRow(int startColumn, int startRow, int direction)
        {
            switch (direction % 4)
            {
                case 2:
                    return (startRow + 1);
                case 0:
                    return (startRow - 1);
                default:
                    return (startRow);
            }
        }
    }
}
