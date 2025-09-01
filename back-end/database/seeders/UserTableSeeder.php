<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class UserTableSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $users = [
            [
                'username' => "admin",
                'first_name' => "Default",
                'last_name' => "User",
                'email' => "admin@clms.com",
                'phone' => "0000000",
                'password' => bcrypt("admin")
            ],
            [
                'username' => "nathaniel",
                'first_name' => "Nathaniel",
                'last_name' => "S.",
                'email' => "nathaniel@clms.com",
                'phone' => "1111111",
                'password' => bcrypt("nathaniel")
            ],
            [
                'username' => "albert",
                'first_name' => "Albert",
                'last_name' => "B.",
                'email' => "albert@clms.com",
                'phone' => "2222222",
                'password' => bcrypt("albert")
            ],
            [
                'username' => "jessy",
                'first_name' => "Jessy",
                'last_name' => "Baki",
                'email' => "jessy@clms.com",
                'phone' => "3333333",
                'password' => bcrypt("jessy")
            ],
        ];

        foreach ($users as $user) {
            User::create($user);
        }
    }
}
