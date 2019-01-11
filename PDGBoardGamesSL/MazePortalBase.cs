using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace PDGBoardGames
{
    public class MazePortalBase
    {
        public bool Open = false;
        public virtual void Clear()
        {
            Open = false;
        }
        public MazePortalBase()
        {
        }
    }
}
