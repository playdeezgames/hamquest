using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace PDGBoardGames
{
    public abstract class BoardCellBase
    {
        public int Column;
        public int Row;
        public abstract void Clear();
    }
}
