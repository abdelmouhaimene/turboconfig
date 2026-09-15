import { Button } from "@repo/ui/button";

export default function Home() {
  return (
    <div className="w-full h-screen bg-red-300 flex justify-center items-center">
      <Button appName="web" className="bg-green-700 text-bold text-lg cursor-pointer hover:bg-green-800 rounded-full">
        Hello
      </Button>
    </div>
  );
}
