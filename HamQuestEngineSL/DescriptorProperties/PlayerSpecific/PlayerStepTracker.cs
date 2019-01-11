using System;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using System.Xml.Linq;

namespace HamQuestEngine
{
    public delegate void StepTrackerEndOfTurnCallback();
    public interface IStepTracker
    {
        int Steps { get; }
        int Total { get; }
        void Reset();
        void Reset(int newTotal);
        void DoStep();
        StepTrackerEndOfTurnCallback OnEndOfTurn{get;}
    }
    public class PlayerStepTracker:IStepTracker
    {
        private int steps = 0;
        private int total = 0;
        private StepTrackerEndOfTurnCallback onEndOfTurn=null;

        public static PlayerStepTracker LoadFromNode(XElement node)
        {
            return new PlayerStepTracker();
        }

        public int Steps
        {
            get { return steps; }
        }

        public int Total
        {
            get { return total; }
        }

        public void Reset()
        {
            steps = 0;
        }

        public void Reset(int newTotal)
        {
            total = newTotal;
            Reset();
        }

        public void DoStep()
        {
            steps++;
            if (Steps >= Total)
            {
                if (OnEndOfTurn != null)
                {
                    OnEndOfTurn();
                }
            }
        }

        public StepTrackerEndOfTurnCallback OnEndOfTurn
        {
            get { return onEndOfTurn; }
            set { onEndOfTurn = value; }
        }
    }
}
