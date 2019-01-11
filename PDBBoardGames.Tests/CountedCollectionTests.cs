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
    public class CountedCollectionTests
    {
        private const string Test = "test";

        [TestMethod]
        public void CountedCollectionOfStringAddOne()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            collection.Add(Test);

            Assert.AreEqual(1,collection.Values.Count);
            Assert.AreEqual((uint)1, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringAddOneTwice()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            collection.Add(Test);
            collection.Add(Test);

            Assert.AreEqual(1, collection.Values.Count);
            Assert.AreEqual((uint)2, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringHasWithEmptyCollection()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            Assert.IsFalse(collection.Has(Test));
            Assert.AreEqual((uint)0, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringRemoveOne()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            collection.Add(Test, 1);
            var result = collection.Remove(Test);

            Assert.IsTrue(result);
            Assert.AreEqual((uint)0, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringRemoveOneLeavingOne()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            collection.Add(Test, 2);
            var result = collection.Remove(Test);

            Assert.IsTrue(result);
            Assert.AreEqual((uint)1, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringRemoveOneFromEmptyCollection()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            var result = collection.Remove(Test);

            Assert.IsFalse(result);
            Assert.AreEqual((uint)0, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringSetItem()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            collection[Test] = (uint)1;

            Assert.AreEqual((uint)1, collection[Test]);
        }

        [TestMethod]
        public void CountedCollectionOfStringSetItemTwice()
        {
            CountedCollection<string> collection = new CountedCollection<string>();

            collection[Test] = (uint)1;
            collection[Test] = (uint)2;

            Assert.AreEqual((uint)2, collection[Test]);
        }


    }
}
