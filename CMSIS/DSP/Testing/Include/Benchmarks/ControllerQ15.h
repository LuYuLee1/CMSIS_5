#include "Test.h"
#include "Pattern.h"
class ControllerQ15:public Client::Suite
    {
        public:
            ControllerQ15(Testing::testID_t id);
            void setUp(Testing::testID_t,std::vector<Testing::param_t>& params,Client::PatternMgr *mgr);
            void tearDown(Testing::testID_t,Client::PatternMgr *mgr);
        private:
            #include "ControllerQ15_decl.h"
            Client::Pattern<q15_t> samples;

            Client::LocalPattern<q15_t> output;
            
            int nbSamples;

            arm_pid_instance_q15  instPid;
            q15_t *pSrc;
            q15_t *pDst;
            
            
    };