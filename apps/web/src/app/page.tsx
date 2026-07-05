import Background from "@/components/Background";
import Hero from "@/components/Hero";
import Features from "@/components/Features";
import AddAccount from "@/components/AddAccount";
import MorningAlarm from "@/components/MorningAlarm";
import Security from "@/components/Security";
import Cta from "@/components/Cta";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <main className="flex flex-1 flex-col">
      <Background />
      <Hero />
      <Features />
      <AddAccount />
      <MorningAlarm />
      <Security />
      <Cta />
      <Footer />
    </main>
  );
}
