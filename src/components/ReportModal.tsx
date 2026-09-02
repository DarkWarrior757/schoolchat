import { useState } from 'react';
import { Flag, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';

const reasons = [
  ['bullying', 'Bullying'],
  ['harassment', 'Harassment'],
  ['spam', 'Spam'],
  ['inappropriate', 'Inappropriate content'],
  ['impersonation', 'Impersonation'],
  ['other', 'Other'],
] as const;

export function ReportModal({ messageId, reportedUserId, reporterId, onClose }: { messageId: string | null; reportedUserId: string; reporterId: string; onClose: () => void }) {
  const [reason, setReason] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  const submit = async () => {
    if (!reason) return;
    setSubmitting(true);
    const { error } = await supabase.from('reports').insert({
      reporter_id: reporterId,
      reported_user_id: reportedUserId,
      message_id: messageId,
      reason,
      description: description.trim(),
    });
    if (!error) { setDone(true); setTimeout(onClose, 1200); }
    setSubmitting(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4" onClick={onClose}>
      <div className="w-full max-w-md rounded-2xl border border-[#263a54] bg-[#101d2e] p-6 shadow-2xl" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <div className="flex items-center gap-3">
            <div className="h-10 w-10 rounded-xl bg-[#4a2233] flex items-center justify-center text-[#ff9eb0]"><Flag size={20} /></div>
            <h3 className="font-display text-lg font-bold text-white">Report to moderators</h3>
          </div>
          <button onClick={onClose} className="rounded-lg p-1.5 text-[#7189a3] hover:bg-[#1a2d43]"><X size={18} /></button>
        </div>

        {done ? (
          <div className="py-8 text-center">
            <div className="mx-auto h-12 w-12 rounded-xl bg-[#174c43] flex items-center justify-center text-[#61d3ad] mb-3"><Flag size={24} /></div>
            <div className="text-sm font-semibold text-white">Report submitted</div>
            <div className="mt-1 text-xs text-[#7189a3]">Moderators will review this report. No action is taken automatically.</div>
          </div>
        ) : (
          <>
            <p className="text-sm text-[#819ab4] mb-5">Help keep SchoolChat safe. Reports are reviewed by authorized moderators — submitting a report does not automatically punish anyone.</p>
            <div className="space-y-2 mb-4">
              <div className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5]">Reason</div>
              <div className="grid grid-cols-2 gap-2">
                {reasons.map(([value, label]) => (
                  <button key={value} onClick={() => setReason(value)} className={`rounded-xl border px-3 py-2.5 text-sm transition ${reason === value ? 'border-[#4ca8ef] bg-[#17304a] text-white' : 'border-[#29435d] bg-[#13263b] text-[#849bb4] hover:border-[#3b6286]'}`}>{label}</button>
                ))}
              </div>
            </div>
            <div className="mb-5">
              <div className="text-xs font-semibold uppercase tracking-wider text-[#7f99b5] mb-2">Additional context (optional)</div>
              <textarea value={description} onChange={e => setDescription(e.target.value)} rows={3} placeholder="Add any details that would help moderators..." className="w-full rounded-xl border border-[#30455f] bg-[#0c1828] px-4 py-3 text-sm text-white outline-none focus:border-[#4ca8ef] resize-none" />
            </div>
            <div className="flex gap-2">
              <button onClick={onClose} className="flex-1 rounded-xl border border-[#3b5874] py-2.5 text-sm text-[#b6c7d7] hover:bg-[#1a2d43]">Cancel</button>
              <button onClick={submit} disabled={!reason || submitting} className="flex-1 rounded-xl bg-[#a44865] py-2.5 text-sm font-semibold text-white hover:bg-[#b85677] disabled:opacity-50">{submitting ? 'Submitting...' : 'Submit report'}</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
