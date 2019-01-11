using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;
using PDGBoardGames;



namespace HamQuestEngine
{
    public class Creature:GameClientBase
    {
        private string creatureIdentifier;
        public bool Summoned = false;
        public bool BeenHit = false;
        private int wounds = 0;
        public int Wounds
        {
            get
            {
                return wounds;
            }
            set
            {
                wounds = (value < 0) ? 0 : value;
            }
        }
        public int Column = 0;
        public int Row = 0;
        public Map Map = null;
        public float Steps = 0.0f;
        public string CreatureIdentifier
        {
            get
            {
                return (creatureIdentifier);
            }
        }
        public bool Dead
        {
            get
            {
                return (Wounds >= Game.TableSet.CreatureTable.GetCreatureDescriptor(CreatureIdentifier).GetHealth());
            }
        }
        public void Remove()
        {
            if (this.Column >= 0 && this.Row >= 0 && this.Column < Map.Columns && this.Row < Map.Rows)
            {
                Map[this.Column][this.Row].Creature = null;
            }
        }
        public void Place()
        {
            if (this.Column >= 0 && this.Row >= 0 && this.Column < Map.Columns && this.Row < Map.Rows)
            {
                Map[this.Column][this.Row].Creature = this;
            }
        }
        public void Move(int direction)
        {
            Remove();
            Directions directions = new Directions();
            int nextColumn = directions.GetNextColumn(this.Column, this.Row, direction);
            int nextRow = directions.GetNextRow(this.Column, this.Row, direction);
            IMover mover = Game.TableSet.CreatureTable.GetCreatureDescriptor(this.CreatureIdentifier).GetProperty<IMover>("mover");
            mover.DoMove(this, ref nextColumn, ref nextRow, Game);
            this.Column = nextColumn;
            this.Row = nextRow;
            Place();
            PlayerDescriptor playerDescriptor = Game.TableSet.CreatureTable.GetCreatureDescriptor(this.CreatureIdentifier) as PlayerDescriptor;
            if (playerDescriptor != null)
            {
                playerDescriptor.UpdatePathfinding();
                playerDescriptor.RevealTraps();
            }
        }
        public int RollAttack()
        {
            int result = 0;
            if (Game.TableSet.CreatureTable.GetCreatureDescriptor(CreatureIdentifier).GetProperty<IStatisticHolder>(GameConstants.Properties.Attack).Value > 0)
            {
                for (int index = 0; index < Game.TableSet.CreatureTable.GetCreatureDescriptor(CreatureIdentifier).GetProperty<IStatisticHolder>(GameConstants.Properties.Attack).Value; ++index)
                {
                    if (Game.RandomNumberGenerator.Next(6) < Game.TableSet.CreatureTable.GetCreatureDescriptor(CreatureIdentifier).GetProperty<int>(GameConstants.Properties.AttackDie))
                    {
                        result++;
                    }
                }
            }
            else
            {
                //unarmed combat
                if (Game.RandomNumberGenerator.Next(6) == 0) result++;
            }
            return (result);
        }
        public int RollDefend()
        {
            return Game.TableSet.CreatureTable.GetCreatureDescriptor(CreatureIdentifier).GetProperty<IRoller>(GameConstants.Properties.DefendRoller).Roll(Game.TableSet.CreatureTable.GetCreatureDescriptor(CreatureIdentifier), Game);
        }
        private Creature():base(null)
        {
        }
        public Creature(string theCreatureIdentifier, int theColumn, int theRow,Game theGame):base(theGame)
        {
            creatureIdentifier = theCreatureIdentifier;
            Column = theColumn;
            Row = theRow;
        }
    }
}
