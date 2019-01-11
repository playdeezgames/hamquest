
namespace HamQuestEngine
{
    public interface IRoller
    {
        int Roll(Descriptor theDescriptor,Game theGame);
        int GetMaximumRoll(Descriptor theDescriptor, Game theGame);
        int GetMinimumRoll(Descriptor theDescriptor, Game theGame);
    }
}
