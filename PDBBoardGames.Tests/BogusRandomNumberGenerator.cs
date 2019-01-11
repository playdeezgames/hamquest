using PDGBoardGames;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PDBBoardGames.Tests
{
    internal class BogusRandomNumberGenerator: IRandomNumberGenerator
    {
        private int seed = 0;

        public int Next(int maximum)
        {
            return Next(0, maximum);
        }

        public int Next(int minimum, int maximum)
        {
            int result = (seed % (maximum - minimum)) + minimum;
            seed++;
            return result;
        }
    }
}
