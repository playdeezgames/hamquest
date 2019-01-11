using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;


namespace HamQuestEngine
{
    public class Portal:MazePortalBase
    {
        private int lockType = 0;
        private bool locked = false;
        public int LockType
        {
            get
            {
                return (lockType);
            }
            set
            {
                lockType = value;
            }
        }
        public bool Locked
        {
            get
            {
                return (locked);
            }
            set
            {
                locked = value;
            }
        }
        public Portal()
            : base()
        {
        }
    }
}
