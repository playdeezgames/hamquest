using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace PDGBoardGames
{
    public class MazeCellInfoBase
    {
        public void Clear()
        {
        }
        public MazeCellInfoBase()
        {
        }
        public virtual object Clone()
        {
            return new MazeCellInfoBase();
        }
    }
}
