using System;
using System.Text;
using System.Collections.Generic;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using PDGBoardGames;

namespace PDBBoardGames.Tests
{
    /// <summary>
    /// Summary description for CountedCollectionTests
    /// </summary>
    [TestClass]
    public class RandomNumberGeneratorTests
    {
        private const int NumberOfTrials = 1000;
        private const int Maximum = 100;
        private const int Minimum = 50;
        private const int Seed = 0;

        [TestMethod]
        public void RandomNumberGeneratorDefaultConstructorNext()
        {
            IRandomNumberGenerator rng = new RandomNumberGenerator();

            for (int index = 0; index < NumberOfTrials; ++index)
            {
                var value = rng.Next(Maximum);
                Assert.IsTrue(value >= 0);
                Assert.IsTrue(value < Maximum);
            }
        }

        [TestMethod]
        public void RandomNumberGeneratorDefaultConstructorNext2()
        {
            IRandomNumberGenerator rng = new RandomNumberGenerator();

            for (int index = 0; index < NumberOfTrials; ++index)
            {
                var value = rng.Next(Minimum,Maximum);
                Assert.IsTrue(value >= Minimum);
                Assert.IsTrue(value < Maximum);
            }
        }

        [TestMethod]
        public void RandomNumberGeneratorSeedConstructorNext()
        {
            IRandomNumberGenerator rng = new RandomNumberGenerator(Seed);
            Random random = new Random(Seed);

            for (int index = 0; index < NumberOfTrials; ++index)
            {
                var value = rng.Next(Maximum);
                Assert.IsTrue(value >= 0);
                Assert.IsTrue(value < Maximum);
                Assert.AreEqual(value, random.Next(Maximum));
            }
        }

        [TestMethod]
        public void RandomNumberGeneratorSeedConstructorNext2()
        {
            IRandomNumberGenerator rng = new RandomNumberGenerator(Seed);
            Random random = new Random(Seed);

            for (int index = 0; index < NumberOfTrials; ++index)
            {
                var value = rng.Next(Minimum, Maximum);
                Assert.IsTrue(value >= Minimum);
                Assert.IsTrue(value < Maximum);
                Assert.AreEqual(value, random.Next(Minimum, Maximum));
            }
        }

    }
}
