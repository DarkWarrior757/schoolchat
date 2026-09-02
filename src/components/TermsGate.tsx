import { useEffect, useState } from 'react';
import { Shield, FileText, Lock, Check, ArrowRight, Radio } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import type { TermsVersion } from '@/types';

export function TermsGate({ userId, onAccepted }: { userId: string; onAccepted: () => void }) {
  const [terms, setTerms] = useState<TermsVersion | null>(null);
  const [loading, setLoading] = useState(true);
  const [accepted, setAccepted] = useState(false);
  const [step, setStep] = useState<'welcome' | 'terms' | 'privacy' | 'profile'>('welcome');

  useEffect(() => {
    (async () => {
      const { data } = await supabase
        .from('terms_versions')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (data) setTerms(data as TermsVersion);

      if (data) {
        const { data: acc } = await supabase
          .from('terms_acceptances')
          .select('id')
          .eq('user_id', userId)
          .eq('terms_version_id', (data as TermsVersion).id)
          .maybeSingle();
        if (acc) { onAccepted(); return; }
      }
      setLoading(false);
    })();
  }, [userId]);

  const accept = async () => {
    if (!terms) return;
    const { error } = await supabase
      .from('terms_acceptances')
      .insert({ user_id: userId, terms_version_id: terms.id });
    if (!error) { setAccepted(true); setTimeout(onAccepted, 600); }
  };

  if (loading) return <div className="min-h-screen bg-[#09111e] flex items-center justify-center"><div className="h-10 w-10 rounded-xl border-2 border-[#367faf] border-t-transparent animate-spin" /></div>;

  const steps = ['welcome', 'terms', 'privacy', 'profile'] as const;
  const stepIndex = steps.indexOf(step);

  return (
    <div className="min-h-screen bg-[#09111e] flex items-center justify-center px-5 py-10 relative overflow-hidden">
      <div className="absolute -top-40 -left-24 h-96 w-96 rounded-full bg-[#165a8f]/25 blur-3xl" />
      <div className="absolute -bottom-48 -right-24 h-[28rem] w-[28rem] rounded-full bg-[#126d69]/20 blur-3xl" />
      <div className="relative w-full max-w-2xl">
        <div className="flex items-center gap-3 mb-8">
          <div className="h-12 w-12 rounded-[15px] bg-[#1f75b6] flex items-center justify-center shadow-xl"><Radio size={25} /></div>
          <div>
            <div className="font-display text-xl font-bold text-white">SchoolChat <span className="text-[#65b8ff]">BETA</span></div>
            <div className="text-xs text-[#7590ae]">Connect. Communicate. Learn.</div>
          </div>
        </div>

        <div className="flex gap-2 mb-6">
          {steps.map((s, i) => (
            <div key={s} className={`h-1.5 flex-1 rounded-full transition ${i <= stepIndex ? 'bg-[#2e8bcf]' : 'bg-[#1d2c41]'}`} />
          ))}
        </div>

        <div className="glass rounded-[28px] border border-[#263a54] shadow-2xl p-7 sm:p-10">
          {step === 'welcome' && (
            <div>
              <div className="h-12 w-12 rounded-xl bg-[#173e62] flex items-center justify-center text-[#71c2ff] mb-5"><Shield size={24} /></div>
              <h2 className="font-display text-3xl font-bold text-white mb-3">Welcome to SchoolChat</h2>
              <p className="text-[#91a7c2] leading-7">Before you start, you'll review your school's rules, accept the Terms & Conditions, read the Privacy Notice, and set up your profile. This keeps SchoolChat safe for everyone.</p>
              <button onClick={() => setStep('terms')} className="mt-8 w-full rounded-xl bg-[#247bbb] py-3.5 font-semibold text-white hover:bg-[#2e8bcf] transition flex items-center justify-center gap-2">Get started <ArrowRight size={18} /></button>
            </div>
          )}

          {step === 'terms' && terms && (
            <div>
              <div className="h-12 w-12 rounded-xl bg-[#173e62] flex items-center justify-center text-[#71c2ff] mb-5"><FileText size={24} /></div>
              <h2 className="font-display text-2xl font-bold text-white mb-1">{terms.title}</h2>
              <div className="text-xs text-[#e2b75c] mb-4">Version {terms.version} — placeholder until replaced by your school's approved wording</div>
              <div className="max-h-64 overflow-y-auto rounded-xl border border-[#263a54] bg-[#0c1828] p-4 text-sm leading-6 text-[#91a7c2] whitespace-pre-wrap">{terms.content}</div>
              <label className="mt-5 flex items-center gap-3 cursor-pointer">
                <input type="checkbox" checked={accepted} onChange={e => setAccepted(e.target.checked)} className="h-5 w-5 rounded accent-[#2e8bcf]" />
                <span className="text-sm text-[#c2d2e1]">I have read and accept the Terms & Conditions</span>
              </label>
              <button onClick={accept} disabled={!accepted} className="mt-6 w-full rounded-xl bg-[#247bbb] py-3.5 font-semibold text-white hover:bg-[#2e8bcf] disabled:opacity-40 transition flex items-center justify-center gap-2">{accepted ? 'Accept and continue' : 'Accept to continue'} <ArrowRight size={18} /></button>
            </div>
          )}

          {step === 'privacy' && (
            <div>
              <div className="h-12 w-12 rounded-xl bg-[#173e62] flex items-center justify-center text-[#71c2ff] mb-5"><Lock size={24} /></div>
              <h2 className="font-display text-2xl font-bold text-white mb-3">Privacy Notice</h2>
              <div className="max-h-64 overflow-y-auto rounded-xl border border-[#263a54] bg-[#0c1828] p-4 text-sm leading-6 text-[#91a7c2] space-y-3">
                <p><strong className="text-[#c2d2e1]">What we collect:</strong> Your display name, username, school email, messages, and friend connections. No phone numbers, home addresses, or private contact details are collected.</p>
                <p><strong className="text-[#c2d2e1]">Why it's needed:</strong> To provide class communication, real-time messaging, and friend connections within your school community.</p>
                <p><strong className="text-[#c2d2e1]">Who can access it:</strong> Authorized members of your school. Teachers and administrators can access messages for moderation and safety. Direct messages are only visible to participants.</p>
                <p><strong className="text-[#c2d2e1]">Moderation:</strong> Reports are reviewed by authorized moderators. Action is not taken automatically based on reports alone.</p>
                <p><strong className="text-[#c2d2e1]">Retention:</strong> Messages are retained according to your school's approved policy.</p>
                <p className="text-[#e2b75c]">This is a placeholder. Replace with your school's officially approved Privacy Notice before production use.</p>
              </div>
              <button onClick={() => setStep('profile')} className="mt-6 w-full rounded-xl bg-[#247bbb] py-3.5 font-semibold text-white hover:bg-[#2e8bcf] transition flex items-center justify-center gap-2">Continue <ArrowRight size={18} /></button>
            </div>
          )}

          {step === 'profile' && (
            <div>
              <div className="h-12 w-12 rounded-xl bg-[#174c43] flex items-center justify-center text-[#61d3ad] mb-5"><Check size={24} /></div>
              <h2 className="font-display text-2xl font-bold text-white mb-3">You're all set</h2>
              <p className="text-[#91a7c2] leading-7">Your profile is ready. You can update your display name, bio, and appearance settings anytime from your profile page.</p>
              <button onClick={onAccepted} className="mt-6 w-full rounded-xl bg-[#237d68] py-3.5 font-semibold text-white hover:bg-[#2b9a82] transition flex items-center justify-center gap-2">Enter SchoolChat <ArrowRight size={18} /></button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
